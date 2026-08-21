import SwiftUI

struct SourcesPickerCard: View {
    @EnvironmentObject private var appState: AppState
    @State private var bookQuery = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kaynak algoritma")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("\(appState.mirrorPick.count)/\(AppState.mirrorMax)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.greenSoft)
                    .clipShape(Capsule())
                Spacer()
                Button("Yenile") {
                    Task { await appState.loadMirrorBooks() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.green)
                .disabled(appState.isLoading)
            }
            Text(appState.mirrorPick.isEmpty
                 ? "En fazla 3 algoritma. Zıt yön aynı sembolde atlanır."
                 : "Çalışan: " + selectedNames)
                .font(.caption)
                .foregroundStyle(Theme.mut)
            TextField("Defter ara…", text: $bookQuery)
                .padding(12)
                .background(Theme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if appState.mirrorRows.isEmpty {
                Text(appState.mirrorHint ?? "Liste yükleniyor…")
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredBooks) { row in
                        bookRow(row)
                    }
                }
            }
            if let hint = appState.mirrorHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(hint.contains("Kaydedildi") ? Theme.green : Theme.red)
            }
            Button {
                Task { saved = await appState.saveMirrorBooks() }
            } label: {
                Text("Algoritmaları kaydet")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Theme.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(appState.isLoading || appState.mirrorPick.isEmpty)
            if saved {
                Text("Kaydedildi").font(.footnote).foregroundStyle(Theme.green)
            }
        }
        .task { await appState.loadMirrorBooks() }
    }

    private var filteredBooks: [MirrorBook] {
        let q = bookQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return appState.mirrorRows }
        return appState.mirrorRows.filter {
            $0.title.lowercased().contains(q) || $0.book.lowercased().contains(q)
        }
    }

    private var selectedNames: String {
        appState.mirrorPick.map { id in
            appState.mirrorRows.first(where: { $0.book == id })?.title ?? id
        }.joined(separator: " + ")
    }

    private func bookRow(_ row: MirrorBook) -> some View {
        let on = appState.mirrorPick.contains(row.book)
        return Button {
            appState.toggleMirrorBook(row.book)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Theme.green : Theme.mut)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if let open = row.open, open > 0 {
                            Text("\(open) açık")
                                .font(.caption2)
                                .foregroundStyle(Theme.mut)
                        }
                    }
                    HStack(spacing: 10) {
                        if let bal = row.balance {
                            Text(Theme.money(bal))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        if let pnl = row.pnl {
                            Text(String(format: "%+.1f", pnl))
                                .font(.caption)
                                .foregroundStyle(Theme.pnlColor(pnl))
                        }
                        Text(row.wrText)
                            .font(.caption)
                            .foregroundStyle(Theme.mut)
                    }
                }
            }
            .padding(12)
            .background(on ? Theme.greenSoft : Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
