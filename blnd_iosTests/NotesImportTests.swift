@testable import blnd_ios
import UIKit
import Testing

struct NotesImportTests {
    @Test func recognizerReadsDrawnText() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 160)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 160))
            let line = "Heat" as NSString
            line.draw(
                at: CGPoint(x: 24, y: 48),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 64, weight: .bold),
                    .foregroundColor: UIColor.black,
                ]
            )
        }

        let text = try NotesTextRecognizer.text(in: [image])

        #expect(text.localizedCaseInsensitiveContains("heat"))
    }
}
