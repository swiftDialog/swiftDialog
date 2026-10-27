//
//  DesktopNotificationMockup.swift
//  dialog
//
//  A drawn specimen of a notification the user will get later, on a simple desktop ground, built
//  from config copy. `autoplay` picks static (already arrived) or slide-in from the right edge.
//  The ground takes a hex, `tile:` or `gradient:` via `GeneratedImageRef.parse`.

import SwiftUI

struct DesktopNotificationMockup: View {
    /// The notification's bold first line.
    let title: String
    /// Its body. One or two lines; the card clips rather than growing, as the real one does.
    var body_: String?
    /// The app name in the small caps line above the title.
    var appName: String?
    /// The desktop ground: a hex, `tile:…`, or `gradient:…`. Absent draws a neutral slate.
    var ground: String?
    /// An SF Symbol for the app tile. Absent draws a bell.
    var symbol: String?
    /// Slide-in when true; absent or false draws the static specimen.
    var animated: Bool = false
    let accent: Color

    @Environment(\.palette) private var palette
    @State private var arrived = false

    private var groundView: some View {
        Group {
            if let ground, let generated = GeneratedImageRef.parse(ground) {
                GeneratedImageView(ref: generated)
            } else if let ground, !ground.isEmpty {
                Color(hex: ground)
            } else {
                // Unauthored ground follows the palette so it tracks the theme.
                LinearGradient(colors: [palette.text.opacity(0.62), palette.text.opacity(0.82)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                groundView

                // A hint of a menu strip: height and translucency only.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.white.opacity(0.16))
                        .frame(height: max(geo.size.height * 0.055, 12))
                        .overlay(alignment: .leading) {
                            Circle().fill(.white.opacity(0.5))
                                .frame(width: 7, height: 7)
                                .padding(.leading, 9)
                        }
                    Spacer(minLength: 0)
                }

                notification
                    .padding(.top, max(geo.size.height * 0.055, 12) + 10)
                    .padding(.trailing, 12)
                    // `arrived` starts false in both states; the static one never waits, so a capture is settled.
                    .offset(x: animated && !arrived ? 60 : 0)
                    .opacity(animated && !arrived ? 0 : 1)
                    .onAppear {
                        guard animated else { arrived = true; return }
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)
                            .delay(0.35)) {
                            arrived = true
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var notification: some View {
        HStack(alignment: .top, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(accent)
                Image(systemName: symbol ?? "bell.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                if let appName, !appName.isEmpty {
                    Text(appName.uppercased())
                        .font(.system(size: 8.5, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let body_, !body_.isEmpty {
                    Text(body_)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(width: 268, alignment: .leading)
        // System material, so the card reads on dark and pale grounds alike.
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
    }
}
