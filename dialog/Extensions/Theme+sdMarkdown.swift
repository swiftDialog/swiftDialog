//
//  Theme+sdMarkdown.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/5/2023.
//

import Foundation
import SwiftUI
import MarkdownUI

extension Theme {
    func basicWithInfoBoxLinkStyle() -> Theme {
        var modifiedTheme = Theme.basic
        modifiedTheme.link = UnderlineStyle(.single)
        return modifiedTheme
    }
}

extension Theme {
  static let sdMarkdown = Theme()
    .code {
        FontFamilyVariant(.monospaced)
        FontSize(.em(0.85))
        ForegroundColor(.code)
        BackgroundColor(.background)
    }
    .blockquote { configuration in
      HStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 6)
              .fill(Color.border)
          .relativeFrame(width: .em(0.2))
        configuration.label
              .markdownTextStyle { ForegroundColor(.secondary) }
          .relativePadding(.horizontal, length: .em(1))
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .codeBlock { configuration in
      ScrollView(.horizontal) {
        configuration.label
          .relativeLineSpacing(.em(0.225))
          .markdownTextStyle {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
          }
          .padding(16)
      }
      .background(Color.secondaryBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .markdownMargin(top: 0, bottom: 16)
    }
    .link {
        ForegroundColor(.link)
    }
    .strong {
          FontWeight(.semibold)
        }
    .codeBlock { configuration in
        ScrollView(.horizontal) {
            configuration.label
                .relativeLineSpacing(.em(0.225))
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.85))
                }
                .padding(16)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .markdownMargin(top: 10, bottom: 10)
    }
    .heading1 { configuration in
      VStack(alignment: .leading, spacing: 0) {
        configuration.label
          .relativePadding(.bottom, length: .em(0.3))
          .relativeLineSpacing(.em(0.125))
          .markdownMargin(top: 24, bottom: 16)
          .markdownTextStyle {
            FontWeight(.semibold)
            FontSize(.em(2))
          }
        Divider().overlay(Color.divider)
      }
    }
    .heading2 { configuration in
      VStack(alignment: .leading, spacing: 0) {
        configuration.label
          .relativePadding(.bottom, length: .em(0.3))
          .relativeLineSpacing(.em(0.125))
          .markdownMargin(top: 24, bottom: 16)
          .markdownTextStyle {
            FontWeight(.semibold)
            FontSize(.em(1.5))
          }
        Divider().overlay(Color.divider)
      }
    }
    .heading3 { configuration in
      configuration.label
        .relativeLineSpacing(.em(0.125))
        .markdownMargin(top: 24, bottom: 16)
        .markdownTextStyle {
          FontWeight(.semibold)
          FontSize(.em(1.25))
        }
    }
    .heading4 { configuration in
      configuration.label
        .relativeLineSpacing(.em(0.125))
        .markdownMargin(top: 24, bottom: 16)
        .markdownTextStyle {
          FontWeight(.semibold)
        }
    }
    .heading5 { configuration in
      configuration.label
        .relativeLineSpacing(.em(0.125))
        .markdownMargin(top: 24, bottom: 16)
        .markdownTextStyle {
          FontWeight(.semibold)
          FontSize(.em(0.875))
        }
    }
    .heading6 { configuration in
      configuration.label
        .relativeLineSpacing(.em(0.125))
        .markdownMargin(top: 24, bottom: 16)
        .markdownTextStyle {
          FontWeight(.semibold)
          FontSize(.em(0.85))
          ForegroundColor(.tertiaryText)
        }
    }
    .table { configuration in
      configuration.label
        .fixedSize(horizontal: false, vertical: true)
        .markdownTableBorderStyle(.init(color: .border))
        .markdownMargin(top: 16, bottom: 16)
        .markdownTableBackgroundStyle(
          .alternatingRows(Color.clear, Color.clear, header: Color.background)
        )
    }
    .tableCell { configuration in
      configuration.label
        .markdownTextStyle {
          if configuration.row == 0 {
            FontWeight(.semibold)
          }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 6)
        .padding(.horizontal, 13)
        .relativeLineSpacing(.em(0.25))
    }
}

