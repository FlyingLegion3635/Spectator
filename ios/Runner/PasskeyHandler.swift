import AuthenticationServices
import Flutter

@available(iOS 16.0, *)
class PasskeyHandler: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var pendingResult: FlutterResult?
    private var operation = ""

    // MARK: - Public entry points

    func handleCreateCredential(options: [String: Any], result: @escaping FlutterResult) {
        pendingResult = result
        operation = "create"

        guard
            let pk = extractPublicKey(from: options),
            let challengeStr = pk["challenge"] as? String,
            let challenge = Data(base64urlEncoded: challengeStr),
            let user = pk["user"] as? [String: Any],
            let userIdStr = user["id"] as? String,
            let userId = Data(base64urlEncoded: userIdStr),
            let rp = pk["rp"] as? [String: Any],
            let rpId = rp["id"] as? String,
            let userName = user["name"] as? String
        else {
            result(FlutterError(code: "INVALID_OPTIONS",
                                message: "Invalid passkey registration options",
                                details: nil))
            return
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: rpId)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: userName,
            userID: userId)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func handleGetCredential(options: [String: Any], result: @escaping FlutterResult) {
        pendingResult = result
        operation = "get"

        guard
            let pk = extractPublicKey(from: options),
            let challengeStr = pk["challenge"] as? String,
            let challenge = Data(base64urlEncoded: challengeStr),
            let rpId = pk["rpId"] as? String
        else {
            result(FlutterError(code: "INVALID_OPTIONS",
                                message: "Invalid passkey authentication options",
                                details: nil))
            return
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)

        if let allowCredentials = pk["allowCredentials"] as? [[String: Any]] {
            request.allowedCredentials = allowCredentials.compactMap { cred in
                guard let idStr = cred["id"] as? String,
                      let idData = Data(base64urlEncoded: idStr) else { return nil }
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(
                    credentialID: idData)
            }
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Helpers

    private func extractPublicKey(from options: [String: Any]) -> [String: Any]? {
        if let pk = options["publicKey"] as? [String: Any] { return pk }
        return options
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { pendingResult = nil }

        if operation == "create",
           let cred = authorization.credential
               as? ASAuthorizationPlatformPublicKeyCredentialRegistration
        {
            let payload: [String: Any] = [
                "id": cred.credentialID.base64urlEncoded(),
                "rawId": cred.credentialID.base64urlEncoded(),
                "type": "public-key",
                "response": [
                    "clientDataJSON": cred.rawClientDataJSON.base64urlEncoded(),
                    "attestationObject": (cred.rawAttestationObject ?? Data())
                        .base64urlEncoded(),
                    "transports": ["internal"],
                ],
                "clientExtensionResults": [:] as [String: Any],
            ]
            pendingResult?(payload)
        } else if operation == "get",
                  let cred = authorization.credential
                      as? ASAuthorizationPlatformPublicKeyCredentialAssertion
        {
            var response: [String: Any] = [
                "clientDataJSON": cred.rawClientDataJSON.base64urlEncoded(),
                "authenticatorData": cred.rawAuthenticatorData.base64urlEncoded(),
                "signature": cred.signature.base64urlEncoded(),
            ]
            if let uid = cred.userID {
                response["userHandle"] = uid.base64urlEncoded()
            }
            let payload: [String: Any] = [
                "id": cred.credentialID.base64urlEncoded(),
                "rawId": cred.credentialID.base64urlEncoded(),
                "type": "public-key",
                "response": response,
                "clientExtensionResults": [:] as [String: Any],
            ]
            pendingResult?(payload)
        } else {
            pendingResult?(FlutterError(code: "UNKNOWN_CREDENTIAL",
                                        message: "Unexpected credential type",
                                        details: nil))
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        defer { pendingResult = nil }
        let asError = error as? ASAuthorizationError
        if asError?.code == .canceled {
            pendingResult?(FlutterError(code: "CANCELLED",
                                        message: "Passkey operation was cancelled",
                                        details: nil))
        } else {
            pendingResult?(FlutterError(code: "ERROR",
                                        message: error.localizedDescription,
                                        details: nil))
        }
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Data base64url helpers

extension Data {
    init?(base64urlEncoded string: String) {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        self.init(base64Encoded: s)
    }

    func base64urlEncoded() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
