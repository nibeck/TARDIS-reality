import SwiftUI
import Observation

struct ControlPanelView: View {
    @Bindable var viewModel: TardisViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "power")
                    Text("Power")
                    Spacer()
                    Toggle("On/Off", isOn: $viewModel.allOnOff)
                        .labelsHidden()
                }
                Divider()
                
                Group {
                    // Top Light Control
                    HStack {
                        Toggle("On/Off", isOn: $viewModel.topLightOnOff)
                            .labelsHidden()
                        Text("Top Light")
                        Spacer()
                        ColorPicker("", selection: $viewModel.topLightColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(!viewModel.topLightOnOff)
                    }
                    // Front Window Control
                    HStack {
                        Toggle("On/Off", isOn: $viewModel.frontWindowOnOff)
                            .labelsHidden()
                        Text("Front Window ")
                        Spacer()

                        ColorPicker("", selection: $viewModel.frontWindowColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(!viewModel.frontWindowOnOff)
                    }
                    // Front Police Sign
                    HStack {
                        Toggle("On/Off", isOn: $viewModel.frontPoliceSignOnOff)
                            .labelsHidden()
                        Text("Front Police Sign")
                        Spacer()
                        ColorPicker("", selection: $viewModel.frontPoliceSignColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(!viewModel.frontPoliceSignOnOff)
                    }
                    // Left Police Sign
                    HStack {
                        Toggle("On/Off", isOn: $viewModel.leftPoliceSignOnOff)
                            .labelsHidden()
                        Text("Left Police Sign")
                        Spacer()
                        ColorPicker("", selection: $viewModel.leftPoliceSignColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(!viewModel.leftPoliceSignOnOff)
                    }
                    // Rear Police Sign
                    HStack {
                        Toggle("On/Off", isOn: $viewModel.rearPoliceSignOnOff)
                            .labelsHidden()
                        Text("Rear Police Sign")
                        Spacer()
                        ColorPicker("", selection: $viewModel.rearPoliceSignColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(!viewModel.rearPoliceSignOnOff)
                    }
                    // Right Police Sign
                    HStack {
                        Toggle("On/Off", isOn: $viewModel.rightPoliceSignOnOff)
                            .labelsHidden()
                        Text("Right Police Sign")
                        Spacer()
                        ColorPicker("", selection: $viewModel.rightPoliceSignColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(!viewModel.rightPoliceSignOnOff)
                    }
                    // Left Window
                    HStack {
                        Toggle("On/Off", isOn: $viewModel.leftWindowOnOff)
                            .labelsHidden()
                        Text("Left Window")
                        Spacer()
                        ColorPicker("", selection: $viewModel.leftWindowColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(!viewModel.leftWindowOnOff)
                    }
                    // Right Window
                    HStack {
                        Toggle("On/Off", isOn: $viewModel.rightWindowOnOff)
                            .labelsHidden()
                        Text("Right Window")
                        Spacer()
                        ColorPicker("", selection: $viewModel.rightWindowColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(!viewModel.rightWindowOnOff)
                    }
                    // Rear Window
                    HStack {
                        Toggle("On/Off", isOn: $viewModel.rearWindowOnOff)
                            .labelsHidden()
                        Text("Rear Window")
                        Spacer()
                        ColorPicker("", selection: $viewModel.rearWindowColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(!viewModel.rearWindowOnOff)
                    }
                }
                .disabled(!viewModel.allOnOff)
            }
            .padding()
        }
    }
}

#Preview {
    TardisContentView()
}
