import SwiftUI
import TARDISAPIClient

struct ControlPanelView: View {
    @Binding var modelScale: Double
    @Binding var modelColor: Color
    @Binding var frontWindowColor: Color
    @Binding var topLightColor: Color
    @Binding var leftWindowColor: Color
    @Binding var rightWindowColor: Color
    @Binding var rearWindowColor: Color
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("TARDIS Control Panel")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Scale Control
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                        Text("Size")
                        Spacer()
                        Slider(value: $modelScale, in: 0.5...3.0)
                        Text("\(String(format: "%.1f", modelScale))x")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                // Color Control
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("TARDIS Color")
                    Spacer()
                    ColorPicker("", selection: $modelColor)
                        .labelsHidden()
                }
                
                // Window Color Control
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Front Window Color")
                    Spacer()
                    ColorPicker("", selection: $frontWindowColor)
                        .labelsHidden()
                }
                
                // Top Light Control
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Top Light Color")
                    Spacer()
                    ColorPicker("", selection: $topLightColor)
                        .labelsHidden()
                        .onChange(of: topLightColor) { _, newColor in
                            TARDISManager.shared.setTopLightColor(newColor)
                        }
                }
                
                // Left Window
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Left Window Color")
                    Spacer()
                    ColorPicker("", selection: $leftWindowColor)
                        .labelsHidden()
                }
                
                // Right Window
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Right Window Color")
                    Spacer()
                    ColorPicker("", selection: $rightWindowColor)
                        .labelsHidden()
                }
                
                // Back Window
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Rear Window Color")
                    Spacer()
                    ColorPicker("", selection: $rearWindowColor)
                        .labelsHidden()
                }
            }
            .padding()
        }
    }
}
