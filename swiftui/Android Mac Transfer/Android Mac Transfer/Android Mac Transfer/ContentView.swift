// 📁 SECTION: Imports & State
import SwiftUI
import AppKit

// 🔚 END SECTION: Imports & State

struct ContentView: View {
    // 📁 SECTION: State Variablen
    @State private var androidPath = "/sdcard"
    @State private var entries: [String] = []
    @State private var selectedEntries: Set<String> = []
    @State private var macTargetPath = ""
    @State private var output = ""
    @State private var progressText = ""
    @State private var progressValue: Double = 0
    // 🔚 END SECTION: State Variablen

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 📂 SECTION: Pfad anzeigen
            Text("📂 Android Pfad: \(androidPath)")
                .font(.headline)
            // 🔚 END SECTION: Pfad anzeigen

            // 🗂️ SECTION: Liste der Ordner & Auswahl
            List(entries, id: \ .self) { entry in
                HStack {
                    Toggle(isOn: Binding(
                        get: { selectedEntries.contains(entry) },
                        set: { isSelected in
                            if isSelected {
                                selectedEntries.insert(entry)
                            } else {
                                selectedEntries.remove(entry)
                            }
                        }
                    )) {
                        Text(entry)
                            .font(.system(.body, design: .monospaced))
                    }
                    Spacer()
                    if entry.hasSuffix("/") {
                        Button("Öffnen") {
                            navigateInto(entry)
                        }
                    }
                }
            }
            .frame(height: 300)
            // 🔚 END SECTION: Liste der Ordner & Auswahl

            // 🔙 SECTION: Navigation
            HStack {
                Button("⬅️ Zurück") {
                    navigateUp()
                }

                Button("🔄 Neu laden") {
                    loadDirectory(path: androidPath)
                }
            }
            // 🔚 END SECTION: Navigation

            Divider()

            // 📁 SECTION: Zielordner wählen
            Button("📁 Zielordner auf dem Mac wählen") {
                if let path = selectMacFolder() {
                    macTargetPath = path
                    output = "Mac-Zielordner:\n\(path)"
                }
            }
            // 🔚 END SECTION: Zielordner wählen

            // 📥 SECTION: Übertragen-Button & Fortschritt
            if !selectedEntries.isEmpty {
                Text("✅ Ausgewählt: \(selectedEntries.joined(separator: ", "))")
                Text("📍 Ziel: \(macTargetPath.isEmpty ? "Nicht gewählt" : macTargetPath)")
                Button("📥 Ausgewählte übertragen") {
                    Task {
                        await transferSelectedEntries()
                    }
                }
                if !progressText.isEmpty {
                    Text("⏳ Fortschritt: \(progressText)")
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            // 🔚 END SECTION: Übertragen-Button & Fortschritt

            Divider()

            // 🖨️ SECTION: Ausgabe
            Text("🖨️ Ergebnis:")
                .font(.headline)
            ScrollView {
                Text(output)
                    .font(.system(size: 12, design: .monospaced))
                    .padding()
            }
            // 🔚 END SECTION: Ausgabe
        }
        .padding()
        .onAppear {
            loadDirectory(path: androidPath)
        }
    }

    // 📂 SECTION: Navigation & Verzeichniswechsel
    func navigateInto(_ folder: String) {
        let clean = folder.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        androidPath += "/\(clean)"
        loadDirectory(path: androidPath)
    }

    func navigateUp() {
        guard androidPath != "/sdcard" else { return }
        androidPath = androidPath.components(separatedBy: "/").dropLast().joined(separator: "/")
        if androidPath.isEmpty { androidPath = "/" }
        loadDirectory(path: androidPath)
    }
    // 🔚 END SECTION: Navigation & Verzeichniswechsel

    // 🗂️ SECTION: ADB-Verzeichnisinhalt laden
    func loadDirectory(path: String) {
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/adb")
        task.arguments = ["shell", "ls", "-p", path]
        task.standardOutput = pipe

        do {
            try task.run()
        } catch {
            output = "❌ Fehler beim Laden von \(path): \(error.localizedDescription)"
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let content = String(decoding: data, as: UTF8.self)

        entries = content
            .split(separator: "\n")
            .map { String($0) }
            .sorted()
    }
    // 🔚 END SECTION: ADB-Verzeichnisinhalt laden

    // 📁 SECTION: Zielordner-Dialog macOS
    func selectMacFolder() -> String? {
        let panel = NSOpenPanel()
        panel.title = "Mac-Zielordner auswählen"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            return panel.url?.path
        }
        return nil
    }
    // 🔚 END SECTION: Zielordner-Dialog macOS

    // 📥 SECTION: Datenübertragung (adb pull) starten
    func transferSelectedEntries() async {
        guard !macTargetPath.isEmpty else {
            output = "❗ Zielordner auf dem Mac wurde nicht gewählt."
            return
        }

        output = "Mac-Zielordner:\n\(macTargetPath)\n"
        let total = selectedEntries.count
        var count = 0

        for (index, entry) in selectedEntries.sorted().enumerated() {
            await MainActor.run {
                let percent = Int((Double(index) / Double(total)) * 100)
                progressText = "\(percent)% – Übertrage: \(entry) (\(index + 1)/\(total))"
            }

            await performAdbPull(entry: entry)

            count += 1
        }

        await MainActor.run {
            progressText = "✅ Fertig. \(count) Einträge übertragen."
        }
    }

    func performAdbPull(entry: String) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let source = "\(androidPath)/\(entry)"
                let destination = macTargetPath

                let task = Process()
                let pipe = Pipe()

                task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/adb")
                task.arguments = ["pull", source, destination]
                task.standardOutput = pipe

                do {
                    try task.run()
                    task.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let result = String(decoding: data, as: UTF8.self)

                    DispatchQueue.main.async {
                        output += "\n✅ \(entry):\n\(result)"
                        continuation.resume()
                    }
                } catch {
                    DispatchQueue.main.async {
                        output += "\n❌ Fehler bei \(entry): \(error.localizedDescription)"
                        continuation.resume()
                    }
                }
            }
        }
    }
    // 🔚 END SECTION: Datenübertragung (adb pull) starten
}
