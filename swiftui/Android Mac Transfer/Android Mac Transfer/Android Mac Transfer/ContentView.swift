import SwiftUI
import AppKit

struct ContentView: View {
    @State private var androidPath = "/sdcard"
    @State private var entries: [String] = []
    @State private var selectedEntry: String? = nil
    @State private var macTargetPath = ""
    @State private var output = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📂 Android Pfad: \(androidPath)")
                .font(.headline)

            List(entries, id: \.self) { entry in
                HStack {
                    Text(entry)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    if entry.hasSuffix("/") {
                        Button("Öffnen") {
                            navigateInto(entry)
                        }
                        Button("Wählen") {
                            selectedEntry = entry
                        }
                    } else {
                        Button("Wählen") {
                            selectedEntry = entry
                        }
                    }
                }
            }
            .frame(height: 300)

            HStack {
                Button("⬅️ Zurück") {
                    navigateUp()
                }

                Button("🔄 Neu laden") {
                    loadDirectory(path: androidPath)
                }
            }

            Divider()

            Button("📁 Zielordner auf dem Mac wählen") {
                if let path = selectMacFolder() {
                    macTargetPath = path
                    output = "Mac-Zielordner:\n\(path)"
                }
            }

            if let selected = selectedEntry {
                Text("✅ Quelle ausgewählt: \(selected)")
                Text("📍 Zielordner: \(macTargetPath.isEmpty ? "Nicht gewählt" : macTargetPath)")
                Button("📥 Jetzt übertragen") {
                    output = pullSelected(entry: selected)
                }
            }

            Divider()

            Text("🖨️ Ergebnis:")
                .font(.headline)
            ScrollView {
                Text(output)
                    .font(.system(size: 12, design: .monospaced))
                    .padding()
            }
        }
        .padding()
        .onAppear {
            loadDirectory(path: androidPath)
        }
    }

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

    func pullSelected(entry: String) -> String {
        guard !macTargetPath.isEmpty else {
            return "❗ Zielordner auf dem Mac wurde nicht gewählt."
        }

        let source = "\(androidPath)/\(entry)"
        let destination = macTargetPath

        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/adb")
        task.arguments = ["pull", source, destination]
        task.standardOutput = pipe

        do {
            try task.run()
        } catch {
            return "❌ Fehler beim Kopieren: \(error.localizedDescription)"
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return "✅ Ergebnis adb pull:\n" + String(decoding: data, as: UTF8.self)
    }
}
