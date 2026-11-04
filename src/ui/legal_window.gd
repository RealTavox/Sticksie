class_name LegalWindow
extends OverlayWindow
## "Impressum & Datenschutz": the Impressum, the privacy notice, what the licences ask the app to
## show (GPLv3 §5 and §6, Godot's and the add-on's MIT notices, the CC BY credit of the thread
## colours) and the DMC trademark note. The long list of Godot's third-party notices is only built when asked for.

const COPYRIGHT := "Copyright © 2026 RealTavox"
const SOURCE_URL := "https://github.com/RealTavox/Sticksie"
const CONTACT_URL := "https://github.com/RealTavox/Sticksie/issues"
const GPL_URL := "https://www.gnu.org/licenses/gpl-3.0.html"
const COLORS_URL := "https://makebead.com"
const COLORS_LICENSE_URL := "https://creativecommons.org/licenses/by/4.0/"
const GITHUB_PRIVACY_URL := "https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement"
const ADDON_LICENSE_PATH := "res://addons/godot_ai/LICENSE"
## The provider, for the Impressum and the privacy notice. web/impressum.html and web/datenschutz.html
## say the same for the page around the app; a test keeps them in step.
const PROVIDER_NAME := "Andreas Stoeß"
const PROVIDER_ADDRESS := "Franz-Von-Sickingen-Straße 21/1\n75038 Oberderdingen"
const CONTACT_EMAIL := "punkt.langatmig0i@icloud.com"

const LICENSE_TEXT := "Dieses Programm ist freie Software: Du darfst es unter den Bedingungen der GNU General Public License, Version 3 oder neuer, weitergeben und verändern. Es wird ohne jede Gewährleistung bereitgestellt, soweit das Gesetz das zulässt; Einzelheiten stehen in der Lizenz."
const COLORS_TEXT := "Color data: craft-color-codes by MakeBead (https://makebead.com), CC BY 4.0, unverändert. Die Farbwerte sind Annäherungen an das echte Garn.\nDMC ist eine Marke ihres Inhabers. Die Farbnummern und -namen dienen nur der Beschreibung; diese App steht in keiner Verbindung zu DMC."
const PRIVACY_APP_TEXT := "Die App hat keine Konten, keine Werbung, keine Cookies und kein Tracking und schickt deine Bilder und Projekte nirgendwohin. Sie bleiben mit deinen Einstellungen auf deinem Gerät, in der Web-Version im Speicher deines Browsers. Das ist nötig, damit die App deine Arbeit behalten kann (§ 25 Abs. 2 Nr. 2 TDDDG). Löschen kannst du sie in der Projektliste oder über die Website-Daten deines Browsers."
const PRIVACY_WEB_TEXT := "Die Web-Version und diese Seiten liegen bei GitHub Pages (GitHub, Inc., USA). Beim Aufruf speichert GitHub deine IP-Adresse aus Sicherheitsgründen, dabei können Daten in die USA gelangen. Wie lange GitHub sie speichert und wie es die Übermittlung absichert, steht in GitHubs Datenschutzerklärung. Rechtsgrundlage ist das berechtigte Interesse an einer sicheren Bereitstellung (Art. 6 Abs. 1 lit. f DSGVO)."
const PRIVACY_CONTACT_TEXT := "Wenn du mir schreibst, nutze ich deine Angaben nur, um dir zu antworten, und lösche sie, wenn sie dafür nicht mehr nötig sind (Art. 6 Abs. 1 lit. f DSGVO). Über GitHub Issues Geschriebenes ist öffentlich."
const PRIVACY_RIGHTS_TEXT := "Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch und kannst dich bei einer Datenschutz-Aufsichtsbehörde beschweren."

var _notices: Label
var _notices_button: Button


func _init() -> void:
	super("Impressum & Datenschutz")
	fill_height = true
	content.add_theme_constant_override("separation", 8)
	_add_heading("Impressum")
	_add_text("Angaben gemäß § 18 Abs. 1 MStV und § 5 DDG")
	_add_text("%s\n%s\nE-Mail: %s" % [PROVIDER_NAME, PROVIDER_ADDRESS, CONTACT_EMAIL])
	_add_text("Sticksie ist ein privates, nicht kommerzielles Projekt.")
	_add_links([["E-Mail schreiben", "mailto:" + CONTACT_EMAIL], ["GitHub Issues", CONTACT_URL]])
	_add_heading("Datenschutz")
	_add_text("Verantwortlich: %s, %s" % [PROVIDER_NAME, PROVIDER_ADDRESS.replace("\n", ", ")])
	_add_text(PRIVACY_APP_TEXT)
	_add_text(PRIVACY_WEB_TEXT)
	_add_text(PRIVACY_CONTACT_TEXT)
	_add_text(PRIVACY_RIGHTS_TEXT)
	_add_links([["Datenschutz bei GitHub", GITHUB_PRIVACY_URL]])
	_add_heading(str(ProjectSettings.get_setting("application/config/name")))
	_add_text(COPYRIGHT)
	_add_text(LICENSE_TEXT)
	_add_links([["Quellcode", SOURCE_URL], ["Lizenz (GPLv3)", GPL_URL]])
	_add_heading("Garnfarben")
	_add_text(COLORS_TEXT)
	_add_links([["MakeBead", COLORS_URL], ["CC BY 4.0", COLORS_LICENSE_URL]])
	_add_heading("Verwendete Software")
	_add_text("Diese App nutzt die Godot Engine und das Add-on Godot AI, beide unter der MIT-Lizenz, und die in Godot enthaltenen Bibliotheken unter ihren eigenen Lizenzen.")
	_notices_button = OverlayWindow.make_button("Lizenztexte anzeigen", -1, show_notices)
	content.add_child(_notices_button)
	_notices = _make_label("")
	_notices.add_theme_font_size_override("font_size", 12)
	_notices.visible = false
	content.add_child(_notices)


## The licence texts of Godot, its bundled libraries and the add-on.
static func notices_text() -> String:
	var parts := PackedStringArray(["Godot Engine\n\n" + Engine.get_license_text()])
	for component: Dictionary in Engine.get_copyright_info():
		var lines := PackedStringArray([str(component["name"])])
		for part: Dictionary in component["parts"]:
			for line: String in part["copyright"]:
				lines.append("© " + line)
			lines.append("Lizenz: " + str(part["license"]))
		parts.append("\n".join(lines))
	var licenses := Engine.get_license_info()
	for license: String in licenses:
		parts.append("%s\n\n%s" % [license, licenses[license]])
	parts.append("Godot AI\n\n" + FileAccess.get_file_as_string(ADDON_LICENSE_PATH))
	return "\n\n――――――\n\n".join(parts)


func show_notices() -> void:
	if _notices.text.is_empty():
		_notices.text = notices_text()
	_notices.visible = true
	_notices_button.visible = false


func _add_heading(text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 17)
	content.add_child(heading)


func _add_text(text: String) -> void:
	content.add_child(_make_label(text))


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A row of buttons, each opening its [text, url] in the browser.
func _add_links(links: Array) -> void:
	var row := HFlowContainer.new()
	for link: Array in links:
		var url: String = link[1]
		row.add_child(OverlayWindow.make_button(link[0], -1, func() -> void: OS.shell_open(url)))
	content.add_child(row)
