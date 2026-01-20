function alarmText(type, value) {
  switch (type) {
    case 'temp':
      return `🌡️ Temperatura poza zakresem: ${value}°C`;
    case 'hum':
      return `💧 Wilgotność poza zakresem: ${value}%`;
    case 'light':
      return `💡 Oświetlenie poza zakresem: ${value}`;
    default:
      return '⚠️ Alarm w szklarni';
  }
}

module.exports = {
  alarmText
};
