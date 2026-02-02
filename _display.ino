#include <heltec_unofficial.h>
#include <Wire.h>

#define VEXT_PIN      36   // Vext control (LOW = ON)
#define OLED_RST_PIN  21   // OLED reset

void oledPowerOnAndReset() {
  pinMode(VEXT_PIN, OUTPUT);
  digitalWrite(VEXT_PIN, LOW);   // turn ON Vext
  delay(50);

  pinMode(OLED_RST_PIN, OUTPUT);
  digitalWrite(OLED_RST_PIN, LOW);
  delay(20);
  digitalWrite(OLED_RST_PIN, HIGH);
  delay(50);
}

void setup() {
  Serial.begin(115200);
  delay(200);

  heltec_setup();

  oledPowerOnAndReset();

  // OLED I2C pins on V3 are GPIO17 (SDA) & GPIO18 (SCL)
  Wire.begin(17, 18);

  display.init();
  display.flipScreenVertically();
  display.setFont(ArialMT_Plain_10);

  display.clear();
  display.drawString(0, 0, "OLED TEST V3");
  display.drawString(0, 12, "If you see this,");
  display.drawString(0, 24, "display works :)");
  display.display();
}

void loop() {}
