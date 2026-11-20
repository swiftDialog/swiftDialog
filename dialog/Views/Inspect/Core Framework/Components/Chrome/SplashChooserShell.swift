//
//  SplashChooserShell.swift
//
//  The screen in front of a flow: a brand mark on a dark ground, stacked doors, a legal line and,
//  when the flow has more than one destination, the destinations as an always-visible radio list
//  above the doors. Everything is authored; nothing here is specific to one kind of flow.
//

import SwiftUI

/// One destination in the chooser.
struct SplashEnvironment: Equatable {
    /// What the pick reports; the title when the config authored no id.
    var id: String?
    let title: String
    let subtitle: String?
}

/// Near-black with two coloured pools, dark in both appearances. Also the `phaseBackground:
/// "splash"` backdrop for later screens, so the splash cross-fades into identical ground. A brand
/// palette tints the pools (first colour top-left, second right) at `poolStrength`.
struct SplashGround: View {
    var pools: [Color] = []

    static let poolStrength: Double = 0.3

    private var leftPool: Color {
        pools.first.map { $0.opacity(Self.poolStrength) } ?? Color(red: 0.227, green: 0.071, blue: 0.188)
    }
    private var rightPool: Color {
        (pools.count > 1 ? pools[1] : pools.first).map { $0.opacity(Self.poolStrength) }
            ?? Color(red: 0.051, green: 0.169, blue: 0.322)
    }

    var body: some View {
        ZStack {
            Color(red: 0.043, green: 0.055, blue: 0.078)          // #0b0e14
            RadialGradient(colors: [leftPool, .clear],
                           center: UnitPoint(x: 0.08, y: 0.04), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [rightPool, .clear],
                           center: UnitPoint(x: 0.85, y: 0.15), startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

struct SplashChooserShell: View {

    // MARK: - Content

    /// Already resolved by the seat; this shell picks no artwork.
    var markPath: String?
    var markBasePath: String?
    var title: String?
    var subtitle: String?
    /// Top to bottom; the first is the filled primary, the rest are outlines.
    let doors: [String]
    var onDoor: (Int) -> Void = { _ in }
    /// Bottom-left legal line. Absent means no line.
    var footnote: String?
    /// Fewer than two means no picker.
    var environments: [SplashEnvironment] = []
    var environmentLabel: String?
    /// Called with the index on each pick; the seat owns what the pick means.
    var onSelectEnvironment: (Int) -> Void = { _ in }
    /// Drawn only with `learnMoreURL`: a link that does nothing is never shown.
    var learnMoreText: String?
    /// A page, video or image shown inside the splash, with Back to return to the choice.
    var learnMoreURL: URL?
    /// Bottom-right overflow button. Absent means no button.
    var onOverflow: (() -> Void)?
    /// The primary door's ring, so the splash and the flow it opens carry one colour.
    var accent: Color = Color(red: 0.039, green: 0.420, blue: 0.839)
    /// Pool tint from the flow's `splash` backdrop palette; empty uses the default pools.
    var groundPools: [Color] = []

    @State private var selected = 0
    @State private var viewing = false

    private var hasPicker: Bool { environments.count > 1 }

    // MARK: - Ground

    private var ground: some View { SplashGround(pools: groundPools) }

    // MARK: - Mark and heading

    @ViewBuilder private var markRow: some View {
        if let markPath {
            BrandMark(path: markPath,
                      box: BrandMarkBox(height: 30, maxWidth: nil),
                      basePath: markBasePath)
        }
    }

    @ViewBuilder private var heading: some View {
        if title != nil || subtitle != nil {
            VStack(spacing: 6) {
                if let title {
                    Text(title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14.5))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .multilineTextAlignment(.center)
            .frame(width: 460)
        }
    }

    // MARK: - Doors
    //
    // A door is never disabled: this screen exists to be left.

    private func door(_ index: Int, _ title: String) -> some View {
        Button { onDoor(index) } label: {
            Text(title)
                .font(.system(size: 16.5, weight: .bold))
                .foregroundStyle(index == 0 ? Color(red: 0.114, green: 0.114, blue: 0.122) : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    if index == 0 {
                        Capsule().fill(.white)
                            .overlay(Capsule().strokeBorder(accent, lineWidth: 2))
                    } else {
                        Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - The picker
    //
    // A plain radio list, always shown: every choice visible, the pick marked by a filled circle
    // and a lifted row, and the whole row clickable.

    private var picker: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let environmentLabel {
                Text(environmentLabel.uppercased())
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(0.25)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 6)
            }
            ForEach(Array(environments.enumerated()), id: \.offset) { index, env in
                if index > 0 {
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.horizontal, 18)
                }
                Button { selected = index; onSelectEnvironment(index) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: index == selected ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 17))
                            .foregroundStyle(index == selected ? accent : .white.opacity(0.35))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(env.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            if let subtitle = env.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(index == selected ? Color.white.opacity(0.07) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(index == selected ? .isSelected : [])
            }
        }
        .frame(width: 460)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(red: 0.082, green: 0.086, blue: 0.110)))          // #15161c
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
    }

    /// Centred under the list, outside the card, so it reads as help rather than a fourth choice.
    @ViewBuilder private var learnMoreLink: some View {
        if let learnMoreText, learnMoreURL != nil {
            Button { withAnimation(.easeOut(duration: 0.16)) { viewing = true } } label: {
                Text(learnMoreText)
                    .font(.system(size: 13.5, weight: .medium))
                    .underline()
                    .foregroundStyle(Color(red: 0.424, green: 0.706, blue: 0.961))
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .padding(.top, -12)                         // sits with the list, not between list and doors
        }
    }

    /// The learn-more page over the whole splash. Back (or Esc) returns to the choice as it was;
    /// leaving tears the player down, so nothing keeps playing.
    private func viewer(_ url: URL) -> some View {
        VStack(spacing: 16) {
            ZStack {
                if let learnMoreText {
                    Text(learnMoreText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                HStack(spacing: 16) {
                    Button { withAnimation(.easeOut(duration: 0.16)) { viewing = false } } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(height: 30)
                            .background(Capsule().fill(.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                }
            }
            .padding(.horizontal, 22).padding(.top, 16)

            GeometryReader { geo in
                IntroMediaPlayer(url: url, autoplay: false, height: geo.size.height, cornerRadius: 12)
            }
            .padding(.horizontal, 32).padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ground)
        .transition(.opacity)
    }

    private var doorStack: some View {
        VStack(spacing: 14) {
            ForEach(Array(doors.enumerated()), id: \.offset) { index, title in
                door(index, title)
            }
        }
        .frame(width: 410)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            ground

            if hasPicker {
                // Mark, heading, choices and doors centred as one column.
                VStack(spacing: 24) {
                    markRow
                    heading
                    picker
                    learnMoreLink
                    doorStack
                }
                .padding(.bottom, 40)                       // clears the footnote
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // No choice to make: the mark holds 210 from the top, the doors 66 below it.
                VStack(spacing: 0) {
                    markRow.padding(.top, 210)
                    doorStack.padding(.top, 66)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    if let footnote {
                        Text(footnote)
                            .font(.system(size: 13.5))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: 520, alignment: .leading)
                            .padding(.leading, 40).padding(.bottom, 34)
                    }
                    Spacer(minLength: 16)
                    if let onOverflow {
                        Button(action: onOverflow) {
                            Text("…")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 34, height: 34)
                                .background(Circle().strokeBorder(.white.opacity(0.30), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("More options")
                        .padding(.trailing, 34).padding(.bottom, 28)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if viewing, let learnMoreURL { viewer(learnMoreURL) }
        }
        .background(ground)
        // Figures are measured from the window's top; the transparent title bar must not inset them.
        .ignoresSafeArea()
    }
}
