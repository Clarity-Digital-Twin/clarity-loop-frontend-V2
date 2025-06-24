import SwiftUI

struct InsightCardView: View {
    let insight: InsightPreviewDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Insight of the Day")
                    .font(.headline)
            }

            Text(insight.narrative)
                .font(.body)
                .lineLimit(3)

            HStack {
                Spacer()
                Text(insight.generatedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}
