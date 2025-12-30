import SwiftUI

extension Color {
    var rgbComponents: (r: Int, g: Int, b: Int) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return (
            r: Int(max(0, min(255, r * 255))),
            g: Int(max(0, min(255, g * 255))),
            b: Int(max(0, min(255, b * 255)))
        )
    }
}
