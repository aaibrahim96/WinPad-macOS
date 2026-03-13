import SwiftUI
import UniformTypeIdentifiers

// 1. Data Model
struct NotePage: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
}

struct ContentView: View {
    @State private var pages = [NotePage(title: "Page 1", content: "")]
    @State private var selectedTabID: UUID?
    @State private var isExporting = false
    
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var showFindReplace = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(pages) { page in
                            // Using a separate View struct for the Tab
                            NoteTab(
                                title: page.title,
                                isSelected: selectedTabID == page.id,
                                onSelect: { selectedTabID = page.id },
                                onClose: { closePage(page.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Button(action: addNewPage) {
                    Image(systemName: "plus").padding(8)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Utility Buttons
                HStack(spacing: 12) {
                    Button(action: { showFindReplace.toggle() }) { Image(systemName: "magnifyingglass") }.buttonStyle(.plain)
                    Button(action: duplicateActiveTab) { Image(systemName: "plus.square.on.square") }.buttonStyle(.plain)
                    Button(action: clearActiveTab) { Image(systemName: "trash") }.buttonStyle(.plain).foregroundColor(.red)
                    Button("Save") { isExporting = true }.buttonStyle(.borderedProminent).controlSize(.small)
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 38)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()

            if showFindReplace {
                HStack {
                    TextField("Find", text: $findText).textFieldStyle(.roundedBorder)
                    TextField("Replace", text: $replaceText).textFieldStyle(.roundedBorder)
                    Button("Replace All") { replaceAll() }.buttonStyle(.bordered)
                }
                .padding(8)
                Divider()
            }

            // Text Editor
            ZStack {
                ForEach(pages) { page in
                    if page.id == selectedTabID {
                        TextEditor(text: binding(for: page.id))
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .id(page.id)
                    }
                }
            }

            Divider()

            // Bottom Ribbon
            HStack {
                if let page = pages.first(where: { $0.id == selectedTabID }) {
                    let words = page.content.split { $0.isWhitespace }.count
                    let chars = page.content.filter { !$0.isWhitespace }.count
                    Text("Words: \(words) | Characters: \(chars)")
                    Spacer()
                    Text("WinPad | Plain Text")
                }
            }
            .padding(.horizontal, 10).frame(height: 22).font(.system(size: 11))
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 700, minHeight: 450)
        .onAppear { if selectedTabID == nil { selectedTabID = pages.first?.id } }
        .fileExporter(
            isPresented: $isExporting,
            document: TextFile(initialText: activePageContent),
            contentType: .plainText,
            defaultFilename: activePageTitle
        ) { _ in }
    }

    // --- HELPERS ---
    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { self.pages.first(where: { $0.id == id })?.content ?? "" },
            set: { newValue in
                if let index = self.pages.firstIndex(where: { $0.id == id }) {
                    self.pages[index].content = newValue
                }
            }
        )
    }

    var activePageContent: String { pages.first(where: { $0.id == selectedTabID })?.content ?? "" }
    var activePageTitle: String { pages.first(where: { $0.id == selectedTabID })?.title ?? "Untitled" }

    func replaceAll() {
        if let index = pages.firstIndex(where: { $0.id == selectedTabID }) {
            pages[index].content = pages[index].content.replacingOccurrences(of: findText, with: replaceText)
        }
    }
    func addNewPage() {
        let newPage = NotePage(title: "Page \(pages.count + 1)", content: "")
        pages.append(newPage)
        selectedTabID = newPage.id
    }
    func closePage(_ id: UUID) {
        pages.removeAll { $0.id == id }
        if selectedTabID == id { selectedTabID = pages.last?.id }
        if pages.isEmpty { addNewPage() }
    }
    func clearActiveTab() {
        if let index = pages.firstIndex(where: { $0.id == selectedTabID }) { pages[index].content = "" }
    }
    func duplicateActiveTab() {
        if let page = pages.first(where: { $0.id == selectedTabID }) {
            let newPage = NotePage(title: "\(page.title) Copy", content: page.content)
            pages.append(newPage)
            selectedTabID = newPage.id
        }
    }
}

// 2. Extracted Tab View (Fixes the Frame/Height error)
struct NoteTab: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(title) { onSelect() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .frame(minWidth: 70, minHeight: 28) // Explicitly using minHeight to avoid conflicts
                .background(isSelected ? Color(NSColor.textBackgroundColor) : Color.clear)

            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 8)).padding(6)
            }
            .buttonStyle(.plain)
        }
        .background(isSelected ? Color.gray.opacity(0.2) : Color.black.opacity(0.05))
        .cornerRadius(4)
    }
}

// 3. File Document Support
struct TextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(initialText: String = "") { self.text = initialText }
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents { text = String(decoding: data, as: UTF8.self) } else { text = "" }
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
