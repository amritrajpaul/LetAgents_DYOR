bool isValidTicker(String ticker) {
  return RegExp(r'^[A-Z0-9.]+$').hasMatch(ticker);
}

