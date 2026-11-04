# Kreuzstich-App – Design

Arbeitstitel: **Kreuzstich**. Eine Hilfs-App, die Pixelart in ein Kreuzstichmuster umwandelt und
einen Stich für Stich durch das Sticken führt. Gebaut mit Godot 4.7, vorrangig für Handys und
Tablets, später eventuell als Web-App.

Grundsatz: Die App ist ein Werkzeug, soll sich aber spielerisch und hochwertig anfühlen – schöne
Fadenoptik, flüssige Animationen, klare Führung.

---

## 1. Import: Pixelart → Muster

- Der Nutzer lädt ein Pixelart-Bild (PNG, JPEG, WebP, GIF, BMP, TGA oder SVG; bei GIF zählt das
  erste Bild). Ein Pixel = ein Kreuzstich.
- Jede Bildfarbe wird auf ein echtes Stickgarn abgebildet (Garnpalette DMC, 489 Farben), damit
  man weiß, welches Garn man braucht. Abgleich über Farbabstand im Lab-Farbraum (CIEDE2000).
  Bildfarben, die auf dasselbe Garn fallen, werden eine Farbe.
- Garnfarben-Daten: craft-color-codes von MakeBead (CC BY 4.0); die Quellenangabe steht in der App
  unter der Farbliste.
- Transparente Pixel bleiben leer (Stoff). Zusätzlich kann man jede Farbe als **„Stoff“**
  markieren (z. B. einen Hintergrund), dann wird sie nicht gestickt. Das geht nur, solange in dem
  Projekt noch nichts gestickt ist.
- Bilder mit mehr als 1000 Pixeln pro Seite werden abgelehnt.
- Hat ein Bild sehr viele Farben (über 2048, z. B. ein Foto oder JPEG-Artefakte), werden die Farben
  vor dem Abgleich gröber abgestuft, damit das Finden der Garne nicht minutenlang dauert.
- Dauert das Laden länger, erscheint ein **Ladehinweis** über dem abgedunkelten Bildschirm: eine
  Reihe Kreuze, die dänisch hin und zurück gestickt wird. Sie läuft nur, solange die App Bilder
  zeichnen kann; blockiert die Arbeit das (Planen einer Farbe im Web, ohne Threads), steht dort
  nur der Hinweis ohne Animation.
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
4. Man bestätigt jeden Schritt per **Knopf**, **Tippen aufs Muster** oder **Leertaste**. Mit
   „Zurück“ (oder Rücktaste) geht es einen Schritt zurück.

### Anzeige

- Angezeigt wird nur, was **bereits gestickt** ist, plus **hervorgehoben** der aktuelle Schritt.
  Noch nicht gestickte Felder sind nicht sichtbar (kein Vorlagen-Overlay).
- Der aktuelle Schritt: Rahmen um den Block, die noch zu stickenden Schenkel blass, ein Punkt dort,
  wo die Nadel zuerst hochkommt. Beim Start einer Farbe zoomt die Ansicht auf den ersten Block.
- Fadenwechsel im Bild: **rot „vernähen“** am letzten Stich des alten Fadens (bei jedem
  Fadenwechsel und wenn eine Farbe fertig ist), **grün „neuer Faden“** am ersten Loch des neuen
  Fadens (auch beim ersten Schritt einer Farbe).

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

Weitere Regeln:

- Blöcke werden gleichmäßig geteilt: 7 Stiche → 4 + 3 (nicht 5 + 2).
- **Innerhalb eines Blocks wird nie übersprungen.** Hat ein Reihenabschnitt eine Lücke, endet der
  Block davor; übersprungen wird nur zwischen Blöcken.
- **Lücken in einer Reihe:** Eine Lücke von höchstens 3 Feldern gehört noch zum selben Abschnitt
  (der Faden springt auf der Rückseite). Eine größere Lücke teilt die Reihe in getrennte
  Abschnitte. Ist in den Einstellungen ein kleineres Sprung-Limit gewählt, gilt dieses.
- **Einzelne Stiche:** Ein Abschnitt aus nur einem Stich wird als einzelnes ganzes Kreuz gestickt
  (erst `/`, dann `\`).
- Automatisch (Standard) beginnt jeder Abschnitt an dem Ende, das insgesamt am wenigsten Faden
  kostet; der dänische Rückweg endet wieder dort. Beim Faden zu bleiben ist wichtiger, als jede
  Reihe in dieselbe Richtung zu sticken. Mit einer gewählten Startecke beginnt dagegen jeder
  Abschnitt auf der Startseite. Die Schenkel ändern sich dadurch nicht: Halbstiche sind immer `/`,
  Gegenstiche immer `\`.

### Reihenfolge: Fläche für Fläche

- Eine Farbe besteht oft aus mehreren getrennten **Flächen**. Abschnitte in benachbarten Reihen
  gehören zur selben Fläche, wenn sie sich überlappen oder schräg berühren.
- Eine Fläche wird **fertig gestickt, bevor die nächste beginnt**.
- **Die Fläche wächst ohne Löcher:** Als Nächstes kommt nur ein Abschnitt in Frage, der an schon
  Gesticktes angrenzt. Es wird also nie eine offene Reihe übersprungen, um später zu ihr
  zurückzukommen.
- **Kürzester Faden:** Innerhalb dieser Regeln plant die App den Weg mit dem wenigsten Faden auf
  der Rückseite, gemessen von Loch zu Loch: welcher Abschnitt als Nächstes kommt, an welchem Ende
  er beginnt und durch welches Loch die Nadel zuerst hoch- und zuletzt runtergeht. Nie kommt die
  Nadel durch das Loch hoch, durch das sie gerade runterging. Kleine Farben werden exakt gelöst,
  größere fast optimal; der Plan ist bei gleichen Einstellungen immer derselbe.
- **Startecke** (Einstellung): Automatisch (empfohlen) beginnt jede Farbe dort, wo es am wenigsten
  Faden kostet. Mit einer gewählten Ecke geht es dort los, jede Reihe läuft von der Startseite aus
  und die Reihen kommen in der gewählten Richtung dran, soweit Fläche für Fläche es erlaubt. Das
  kostet mehr Faden.
- Wirkung im Beispielbild: Ohne Sprung-Limit läuft der Faden auf der Rückseite insgesamt 5 648 statt
  5 837 Felder (0,1 % über dem rechnerischen Optimum); mit fester Stickführung 6 139 statt 7 676.

### Smarte Positionshinweise

Nicht nur „zähle 7 Löcher ab“, sondern Bezug auf markante Stellen, die schon gestickt sind, z. B.:

- „direkt unter dem letzten Stich der Reihe davor“,
- „ein Feld rechts neben dem roten Stich“,
- „in der Ecke des schon gestickten Blocks“.

Gezählt wird nur, wenn es keinen guten Bezugspunkt gibt, und dann möglichst wenig.

Umsetzung:

- **Bezugspunkt** ist immer ein Stich, den man auf dem Stoff wiederfindet: der **eigene letzte
  Stich** (dort ist die Nadel) oder ein **Ende einer Stichreihe** (links oder rechts daneben ist
  Stoff oder ein anders aussehender Stich: andere Farbe, Halbstich neben Kreuz). Ein Stich mitten
  in einer Reihe gleicher Stiche ist nie Bezugspunkt. Jede Farbe kann Bezugspunkt sein.
- Von diesen gewinnt der nächste; bei gleichem Abstand eine gerade Linie und dann die eigene Reihe.
- **Im Bild:** blauer Ring um den Bezugspunkt, Linie mit Pfeil zum Start des Blocks, die zu
  zählenden Felder nummeriert (1, 2, 3 …). Bei direkt benachbartem Start keine Zahlen.
- **Im Text** dasselbe, z. B. „Ab deinem letzten Stich zählen: 4 nach links, dann 1 nach unten“
  oder „Direkt rechts neben dem markierten Kreuz (DMC 3837) am linken Ende“.
- Rückweg (Gegenstiche): kein Zählen, er läuft über die eigenen Halbstiche.
- Allererster Stich eines Projekts: Stelle frei wählen; die App sagt, wie viel Platz das Muster
  links und oben davon noch braucht.

### Faden neu

- Jederzeit per Knopf **„Neuer Faden ab hier“**: vor dem aktuellen Schritt wird ein neuer Faden
  genommen (nochmal drücken nimmt es zurück). Das wird gespeichert und im Stickbild berücksichtigt
  (Fadenende vernähen, neuer Anfang, später sichtbar in der Rückseitenansicht).
- **Automatisch nach Sprung-Limit:** In den Einstellungen legt man fest, wie viele Felder der
  Faden auf der Rückseite höchstens überspringen darf. Ist der Weg zum nächsten Schritt länger,
  sagt die App „Neuer Faden: alten Faden unter 3–5 Stichen vernähen, dann neu anfangen“.
  **Standard: 3 Felder** (empfohlen); aus heißt, der Faden wird nie automatisch gewechselt.
  Gezählt werden die Felder
  zwischen dem letzten Stich und dem nächsten (der direkte Nachbar, auch schräg oder in der
  nächsten Reihe, zählt als 0).
- Ohne Fadenwechsel nennt die App längere Wege: „Faden auf der Rückseite 4 Felder weiterführen“.
- Später: Die App schlägt selbst vor, wann ein Faden aufgebraucht ist (geschätzte Fadenlänge).

### Speichern

- Jeder Schritt, jedes Zurück, jeder Fadenwechsel und jede Stoff-Auswahl wird sofort gespeichert.
  Beim Start öffnet sich das zuletzt bearbeitete Projekt; über „Projekte“ wechselt man.
- Jedes geöffnete Bild wird ein eigenes Projekt (Name aus dem Dateinamen). Das Bild wird mit
  gespeichert, das Original darf also verschoben oder gelöscht werden.
- Der Fortschritt ist so gespeichert, dass er auch nach Regeländerungen (andere Einstellungen,
  neue App-Version) an denselben Stichen bleibt: Gespeichert ist, welche Felder gestickt sind.
  Ändert sich die Reihenfolge, gilt jeder Schritt als erledigt, den der Stoff schon zeigt; weiter
  geht es mit dem ersten offenen.

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

- **Sprung-Limit** für automatische Fadenwechsel (siehe „Faden neu“): 3 Felder (Standard), aus
  oder eine andere Anzahl Felder. *(umgesetzt)*
- **Stickrichtung** nach Vorliebe: automatisch (Standard) oder eine Startecke, also Reihenfolge der
  Reihen (oben → unten oder unten → oben) und Startseite (links oder rechts); siehe
  „Reihenfolge“. *(umgesetzt)*
- Richtung des oberen Schenkels und wo die Nadel hochkommt (Stickführung): automatisch (Standard)
  oder fest. *(umgesetzt)*
- Wer von den empfohlenen Einstellungen abweicht, sieht dort den Hinweis, dass das deutlich mehr
  Faden braucht und nicht so gründlich optimiert ist wie die Automatik.

## 5. Plattformen

- Vorrangig Handys und Tablets (Android, iOS), Hoch- und Querformat.
- Eventuell Web-App.
- Renderer: Compatibility (läuft auf älteren Geräten und im Web).
- Stromsparmodus aktiv: nur neu zeichnen, wenn sich etwas ändert.

## 6. Später

- Pixelart-Editor direkt in der App.

---

## Offene Punkte

- **Wege unter fertigen Stichen:** Auf der Rückseite darf der Faden auch weiter laufen, wenn er
  unter schon gestickten Stichen durchgezogen wird. Das Sprung-Limit zählt bisher nur Felder.
- Stoffart und Garnstärke (z. B. Aida 14 ct, 2 Fäden) für die Fadenlängen-Schätzung.
- Projekte löschen und umbenennen; „Beispiel“ legt bisher jedes Mal ein neues Projekt an.
- Im Querformat ist die Schrift sehr klein (Fenstereinstellungen sind auf Hochformat ausgelegt).

Geklärt (siehe oben): Lücken in einer Reihe, einzelne verstreute Stiche, Fortschritt speichern,
Reihenfolge nach Flächen.

## Reihenfolge der Umsetzung

1. Bild importieren, Raster mit Garnfarben darstellen. *(erledigt)*
2. Stichplaner: Reihenfolge, Blöcke ≤ 5, Hinweise, Fadenwechsel. *(erledigt, außer
   Fadenlängen-Schätzung)*
3. Geführtes Sticken: Hervorhebung, Bestätigen, Fortschritt speichern. *(erledigt, schlicht)*
4. Optik: 3D-Faden, Rückseite, Flip.
5. Animationen Anfang und Ende.
6. Pixelart-Editor.

Die Punkte 1–3 sind das Herzstück: zuerst schlicht bauen, dann schön machen.
