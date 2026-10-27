# Kreuzstich-App – Design

Arbeitstitel: **Kreuzstich**. Eine Hilfs-App, die Pixelart in ein Kreuzstichmuster umwandelt und
einen Stich für Stich durch das Sticken führt. Gebaut mit Godot 4.7, vorrangig für Handys und
Tablets, später eventuell als Web-App.

Grundsatz: Die App ist ein Werkzeug, soll sich aber spielerisch und hochwertig anfühlen – schöne
Fadenoptik, flüssige Animationen, klare Führung.

---

## 1. Import: Pixelart → Muster

- Der Nutzer lädt ein Pixelart-Bild (PNG). Ein Pixel = ein Kreuzstich.
- Jede Bildfarbe wird auf ein echtes Stickgarn abgebildet (Garnpalette, z. B. DMC), damit man weiß,
  welches Garn man braucht. Abgleich über Farbabstand im Lab-Farbraum.
- Transparente Pixel bleiben leer (Stoff).
- Ergebnis: Raster mit Garnfarbe pro Feld, Farbliste mit Anzahl Stichen pro Farbe.

## 2. Geführtes Sticken

### Ablauf

1. Man sieht ein leeres digitales Stickraster (Stoff).
2. Man wählt die Farbe, die man sticken will.
3. Die App führt durch jeden Schritt:
   - welche Farbe jetzt dran ist,
   - wo der erste Stich gesetzt wird,
   - wie viele Stiche nacheinander kommen,
   - und so weiter bis die Farbe fertig ist.
4. Man bestätigt jeden Schritt per **Tippen** oder **Leertaste**.

### Anzeige

- Angezeigt wird nur, was **bereits gestickt** ist, plus **hervorgehoben** der aktuelle Schritt.
  Noch nicht gestickte Felder sind nicht sichtbar (kein Vorlagen-Overlay).

### Stichmethode: dänisch

Nicht englisch (jedes Kreuz einzeln), sondern dänisch:

- erst die Halbstiche einer Reihe in eine Richtung (`////`),
- dann auf dem Rückweg die Gegenstiche (`\\\\`), die die Kreuze vollenden,
- dann die nächste Reihe.

Der obere Schenkel zeigt bei allen Kreuzen in dieselbe Richtung.

### Blöcke: höchstens 5 in eine Richtung

Ein Schritt umfasst höchstens **5 Stiche in eine Richtung**. Lieber mehrere kleine Blöcke als
einen großen. Beispiel für 10 Felder in einer Reihe:

1. Block 5 nach rechts (Halbstiche)
2. Block 5 nach rechts (Halbstiche)
3. Block 5 zurück (Gegenstiche)
4. Block 5 zurück (Gegenstiche)

### Smarte Positionshinweise

Nicht nur „zähle 7 Löcher ab“, sondern Bezug auf markante Stellen, die schon gestickt sind, z. B.:

- „direkt unter dem letzten Stich der Reihe davor“,
- „ein Feld rechts neben dem roten Stich“,
- „in der Ecke des schon gestickten Blocks“.

Gezählt wird nur, wenn es keinen guten Bezugspunkt gibt, und dann möglichst wenig.

### Faden neu

- Jederzeit per Knopf: „Ich muss den Faden neu machen“. Das wird im Stickbild berücksichtigt
  (Fadenende vernähen, neuer Anfang, sichtbar in der Rückseitenansicht).
- Die App kann zusätzlich selbst vorschlagen, wann ein Faden aufgebraucht ist (geschätzte
  Fadenlänge).

## 3. Optik und Ansichten

- Sehr ansprechend gestaltet, Faden mit 3D-Wirkung.
- **Vorderseite** (Standard) und optional **Rückseite**. Die Rückseite zeigt, was man tatsächlich
  mit dem Faden gemacht hat (bei der dänischen Methode senkrechte Stiche, Übergänge, Anfänge und
  Enden). So findet man auf der echten Rückseite schneller das richtige Loch.
- Feste Ansichten (kein freies Drehen), Wechsel mit einer schön animierten **Flip**-Animation.
- Der Faden selbst ist animiert, wenn ein Stich gesetzt wird.
- Animation **„Wie fange ich an“** (Faden befestigen am Anfang).
- Animation **„Wie befestige ich den Faden am Ende“**.

Technischer Ansatz: 3D-Szene mit fester orthografischer Kamera, Stiche als MultiMesh. Der Flip ist
eine 180°-Drehung des Stoffs; Vorder- und Rückseite entstehen aus demselben Fadenverlauf.

## 4. Einstellungen

- **Stickrichtung** nach Vorliebe: Reihenfolge der Reihen (oben → unten oder unten → oben) und
  Startseite (links oder rechts).
- Richtung des oberen Schenkels.

## 5. Plattformen

- Vorrangig Handys und Tablets (Android, iOS), Hoch- und Querformat.
- Eventuell Web-App.
- Renderer: Compatibility (läuft auf älteren Geräten und im Web).
- Stromsparmodus aktiv: nur neu zeichnen, wenn sich etwas ändert.

## 6. Später

- Pixelart-Editor direkt in der App.

---

## Offene Punkte

- **Lücken in einer Reihe:** Der Faden darf auf der Rückseite nur kurze Strecken springen (etwa 2–3
  Felder). Größere Lücken teilen die Reihe in getrennte Abschnitte.
- **Einzelne verstreute Stiche:** Hier passt die dänische Methode nicht; Ausweichen auf einzelne
  ganze Kreuze.
- **Fortschritt speichern:** Ein Stickprojekt dauert Tage bis Wochen; der Stand muss sicher
  gespeichert werden.
- Stoffart und Garnstärke (z. B. Aida 14 ct, 2 Fäden) für die Fadenlängen-Schätzung.

## Reihenfolge der Umsetzung

1. Bild importieren, Raster mit Garnfarben darstellen.
2. Stichplaner: Reihenfolge, Blöcke ≤ 5, Hinweise, Fadenwechsel.
3. Geführtes Sticken: Hervorhebung, Bestätigen, Fortschritt speichern.
4. Optik: 3D-Faden, Rückseite, Flip.
5. Animationen Anfang und Ende.
6. Pixelart-Editor.

Die Punkte 1–3 sind das Herzstück: zuerst schlicht bauen, dann schön machen.
