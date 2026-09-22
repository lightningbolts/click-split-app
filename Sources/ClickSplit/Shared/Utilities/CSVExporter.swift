import Foundation

/// Utility for generating CSV files from group expenses for native export.
public enum CSVExporter {
    /// Generates CSV data formatted for spreadsheet import.
    public static func generateCSV(
        groupName: String,
        expenses: [SplitExpense],
        members: [SplitGroupMember]
    ) -> String {
        var csv = "Date,Description,Total Amount,Paid By,Split Method\n"

        let memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.userId, $0.profile?.displayName ?? "Member") })
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        for expense in expenses {
            let dateStr = dateFormatter.string(from: expense.createdAt)
            let descClean = expense.description.replacingOccurrences(of: ",", with: " ")
            let payer = memberMap[expense.paidBy] ?? "Member"
            let total = String(describing: expense.totalAmount)
            let method = expense.splitMethod.description

            csv.append("\(dateStr),\(descClean),\(total),\(payer),\(method)\n")
        }

        return csv
    }

    /// Writes CSV data to a temporary file URL suitable for ShareLink or file export.
    public static func createTemporaryCSVFile(
        groupName: String,
        csvString: String
    ) -> URL? {
        let cleanName = groupName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
        let fileName = "\(cleanName)_expenses.csv"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}
