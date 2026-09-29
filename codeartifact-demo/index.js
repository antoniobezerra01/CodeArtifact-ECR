function formatServiceName(value) {
  if (typeof value !== 'string') {
    throw new TypeError('value must be a string');
  }

  return value.trim().replace(/\s+/g, ' ');
}

module.exports = {
  formatServiceName
};
