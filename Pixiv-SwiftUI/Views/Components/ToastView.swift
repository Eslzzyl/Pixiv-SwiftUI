import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .modifier(ToastBackgroundModifier())
            .shadow(color: Color.black.opacity(0.1), radius: 10)
            .padding(.bottom, 50)
    }
}

struct ToastBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, visionOS 1.0, *) {
            content.glassEffect(in: .rect(cornerRadius: 20))
        } else {
            content
                .background(.ultraThinMaterial)
                .cornerRadius(20)
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(100)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        withAnimation {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, duration: TimeInterval = 2.0) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, duration: duration))
    }
}
