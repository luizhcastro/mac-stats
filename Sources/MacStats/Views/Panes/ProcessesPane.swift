import SwiftUI
import AppKit

enum ProcSortKey: String, CaseIterable {
    case name, pid, cpu, memory, diskRead, diskWrite, netIn, netOut
}

struct ProcessesPane: View {
    @ObservedObject var stats: SystemStats
    @State private var query: String = ""
    @State private var sortKey: ProcSortKey = .cpu
    @State private var sortAscending: Bool = false
    @State private var selection: Int32?
    @State private var rows: [ProcessRow] = []
    @State private var totalCount: Int = 0

    private static let rowHeight: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(
                title: "Processes",
                subtitle: subtitle,
                trailing: AnyView(toolbar)
            )
            .padding(.horizontal, 24)
            .padding(.top, 24)

            tableHeader
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
                .background(Color(nsColor: .underPageBackgroundColor).opacity(0.6))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        ProcessRowView(row: row, isSelected: selection == row.pid)
                            .frame(height: Self.rowHeight)
                            .padding(.horizontal, 24)
                            .background(rowBackground(for: row))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selection = row.pid
                            }
                            .contextMenu {
                                Button("Quit") {
                                    ProcessKill.confirmAndKill(pid: row.pid, name: row.name, mode: .quit)
                                }
                                Button("Force Kill") {
                                    ProcessKill.confirmAndKill(pid: row.pid, name: row.name, mode: .forceKill)
                                }
                            }
                    }
                }
            }
        }
        .onAppear {
            stats.retainNetworkProcessSampling()
            rebuild()
        }
        .onDisappear { stats.releaseNetworkProcessSampling() }
        .onReceive(stats.$snapshot) { snap in
            rebuild(from: snap.allProcesses)
        }
        .onChange(of: query) { _ in rebuild() }
        .onChange(of: sortKey) { _ in resort() }
        .onChange(of: sortAscending) { _ in resort() }
    }

    private func rowBackground(for row: ProcessRow) -> Color {
        if selection == row.pid {
            return Color.accentColor.opacity(0.18)
        }
        return Color.clear
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            headerCell("Name", key: .name, width: nil, align: .leading)
            headerCell("PID", key: .pid, width: 70, align: .trailing)
            headerCell("CPU", key: .cpu, width: 70, align: .trailing)
            headerCell("Memory", key: .memory, width: 100, align: .trailing)
            headerCell("Disk R", key: .diskRead, width: 90, align: .trailing)
            headerCell("Disk W", key: .diskWrite, width: 90, align: .trailing)
            headerCell("Net In", key: .netIn, width: 90, align: .trailing)
            headerCell("Net Out", key: .netOut, width: 90, align: .trailing)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func headerCell(_ title: String, key: ProcSortKey, width: CGFloat?, align: Alignment) -> some View {
        Button {
            if sortKey == key {
                sortAscending.toggle()
            } else {
                sortKey = key
                sortAscending = false
            }
        } label: {
            HStack(spacing: 4) {
                if align == .trailing { Spacer(minLength: 0) }
                Text(title)
                if sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                if align == .leading { Spacer(minLength: 0) }
            }
            .frame(width: width, alignment: align)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: align)
    }

    private var subtitle: String {
        if query.isEmpty {
            return "\(totalCount) running"
        }
        return "\(rows.count) of \(totalCount) match"
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter…", text: $query)
                    .textFieldStyle(.plain)
                    .frame(width: 180)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            if let pid = selection,
               let row = rows.first(where: { $0.pid == pid }) {
                Button {
                    ProcessKill.confirmAndKill(pid: pid, name: row.name, mode: .quit)
                } label: {
                    Label("Quit", systemImage: "xmark.circle")
                }
                .help("Send SIGTERM")
            }
        }
    }

    private func rebuild(from source: [ProcessMonitor.ProcStat]? = nil) {
        let src = source ?? stats.allProcesses
        totalCount = src.count
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var built: [ProcessRow] = []
        built.reserveCapacity(src.count)
        for p in src {
            if !q.isEmpty {
                if !p.name.lowercased().contains(q) && !"\(p.id)".contains(q) {
                    continue
                }
            }
            built.append(ProcessRow(
                pid: p.id,
                name: p.name,
                cpuPercent: p.cpuPercent,
                memoryBytes: p.memoryBytes,
                diskRead: p.diskReadPerSec,
                diskWrite: p.diskWritePerSec,
                netIn: p.netInPerSec,
                netOut: p.netOutPerSec
            ))
        }
        sortInPlace(&built)
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { rows = built }
    }

    private func resort() {
        var sorted = rows
        sortInPlace(&sorted)
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { rows = sorted }
    }

    private func sortInPlace(_ arr: inout [ProcessRow]) {
        let asc = sortAscending
        switch sortKey {
        case .name:      arr.sort { asc ? $0.name < $1.name : $0.name > $1.name }
        case .pid:       arr.sort { asc ? $0.pid < $1.pid : $0.pid > $1.pid }
        case .cpu:       arr.sort { asc ? $0.cpuPercent < $1.cpuPercent : $0.cpuPercent > $1.cpuPercent }
        case .memory:    arr.sort { asc ? $0.memoryBytes < $1.memoryBytes : $0.memoryBytes > $1.memoryBytes }
        case .diskRead:  arr.sort { asc ? $0.diskRead < $1.diskRead : $0.diskRead > $1.diskRead }
        case .diskWrite: arr.sort { asc ? $0.diskWrite < $1.diskWrite : $0.diskWrite > $1.diskWrite }
        case .netIn:     arr.sort { asc ? $0.netIn < $1.netIn : $0.netIn > $1.netIn }
        case .netOut:    arr.sort { asc ? $0.netOut < $1.netOut : $0.netOut > $1.netOut }
        }
    }
}

private struct ProcessRowView: View, Equatable {
    let row: ProcessRow
    let isSelected: Bool

    nonisolated static func == (lhs: ProcessRowView, rhs: ProcessRowView) -> Bool {
        lhs.row == rhs.row && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(row.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(row.pid)")
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
            Text(String(format: "%.2f%%", row.cpuPercent))
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
            Text(Fmt.bytes(row.memoryBytes))
                .monospacedDigit()
                .frame(width: 100, alignment: .trailing)
            Text(Fmt.compactRate(row.diskRead))
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
            Text(Fmt.compactRate(row.diskWrite))
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
            Text(Fmt.compactRate(row.netIn))
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
            Text(Fmt.compactRate(row.netOut))
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
        }
        .font(.system(size: 12))
    }
}

struct ProcessRow: Identifiable, Equatable {
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memoryBytes: UInt64
    let diskRead: Double
    let diskWrite: Double
    let netIn: Double
    let netOut: Double

    var id: Int32 { pid }
}
