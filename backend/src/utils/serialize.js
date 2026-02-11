function isTimestamp(value) {
  return value && typeof value.toDate === 'function';
}

function serializeValue(value) {
  if (isTimestamp(value)) {
    return value.toDate().toISOString();
  }

  if (Array.isArray(value)) {
    return value.map(serializeValue);
  }

  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, child]) => [key, serializeValue(child)]),
    );
  }

  return value;
}

function serializeDoc(docSnap) {
  return {
    id: docSnap.id,
    ...serializeValue(docSnap.data()),
  };
}

module.exports = { serializeDoc, serializeValue };
