//
//  FilterChip.swift
//  clarity-loop-frontend-v2
//
//  Reusable filter chip component for selections
//

import SwiftUI

public struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                #if os(iOS)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                #else
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                #endif
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel("\(title) filter")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select")
    }
}

// MARK: - SwiftUI Preview
#if DEBUG
struct FilterChip_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            FilterChip(title: "All", isSelected: true, action: {})
            FilterChip(title: "Heart Rate", isSelected: false, action: {})
            FilterChip(title: "Steps", isSelected: false, action: {})
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
