import SwiftUI

/// 星星评分组件
struct StarRating: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 14
    var color: Color = .yellow
    var interactive: Bool = true

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .resizable()
                    .frame(width: size, height: size)
                    .foregroundStyle(star <= rating ? color : Color.gray.opacity(0.3))
                    .help("\(star)星")
                    .onTapGesture {
                        if interactive {
                            // 再次点击同一颗星清除评分
                            rating = (rating == star) ? 0 : star
                        }
                    }
                    .onHover { hovering in
                        if interactive && hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
        }
    }
}

/// 只读评分显示（小尺寸，用于卡片）
struct StarRatingDisplay: View {
    let rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 11
    var color: Color = .yellow

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .resizable()
                    .frame(width: size, height: size)
                    .foregroundStyle(star <= rating ? color : Color.gray.opacity(0.25))
            }
        }
    }
}
