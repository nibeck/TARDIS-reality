import SwiftUI
import Observation

struct ControlPanelView: View {
    @Bindable var viewModel: TardisViewModel
    
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
                        Slider(value: $viewModel.modelScale, in: 0.5...3.0)
                        Text("\(String(format: "%.1f", viewModel.modelScale))x")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                HStack {
                    Image(systemName: "power")
                    Text("All Lights")
                    Spacer()
                    Toggle("All On/Off", isOn: $viewModel.allOnOff)
                        .labelsHidden()
                }
                Divider()
                // Color Control
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("TARDIS Color")
                    Spacer()
                    ColorPicker("", selection: $viewModel.modelColor)
                        .labelsHidden()
                }
                
                // Window Color Control
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Front Window Color")
                    Spacer()
                    ColorPicker("", selection: $viewModel.frontWindowColor)
                        .labelsHidden()
                }
                
                // Top Light Control
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Top Light Color")
                    Spacer()
                    ColorPicker("", selection: $viewModel.topLightColor)
                        .labelsHidden()
                }
                
                // Left Window
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Left Window Color")
                    Spacer()
                    ColorPicker("", selection: $viewModel.leftWindowColor)
                        .labelsHidden()
                }
                
                // Right Window
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Right Window Color")
                    Spacer()
                    ColorPicker("", selection: $viewModel.rightWindowColor)
                        .labelsHidden()
                }
                
                // Back Window
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Rear Window Color")
                    Spacer()
                    ColorPicker("", selection: $viewModel.rearWindowColor)
                        .labelsHidden()
                }
            }
            .padding()
        }
    }
}
