import SwiftUI

/// Renders the Google "G" logo (multicolor) without any container or border.
struct GoogleGLogo: View {
  var size: CGFloat = 24

  var body: some View {
    Canvas { context, canvasSize in
      let scale = min(canvasSize.width, canvasSize.height) / 44
      let offsetX = (canvasSize.width - 44 * scale) / 2
      let offsetY = (canvasSize.height - 44 * scale) / 2
      let transform = CGAffineTransform(scaleX: scale, y: scale)
        .translatedBy(x: offsetX / scale, y: offsetY / scale)

      // Blue segment - from SVG path
      let bluePath = Path { p in
        p.move(to: CGPoint(x: 31.6, y: 22.2273))
        p.addCurve(
          to: CGPoint(x: 31.4182, y: 20.1818),
          control1: CGPoint(x: 31.6, y: 21.5182),
          control2: CGPoint(x: 31.5364, y: 20.8364)
        )
        p.addLine(to: CGPoint(x: 22, y: 20.1818))
        p.addLine(to: CGPoint(x: 22, y: 24.05))
        p.addLine(to: CGPoint(x: 27.3818, y: 24.05))
        p.addCurve(
          to: CGPoint(x: 25.3864, y: 27.0682),
          control1: CGPoint(x: 27.15, y: 25.3),
          control2: CGPoint(x: 26.4455, y: 26.3591)
        )
        p.addLine(to: CGPoint(x: 25.3864, y: 29.5773))
        p.addLine(to: CGPoint(x: 28.6182, y: 29.5773))
        p.addCurve(
          to: CGPoint(x: 31.6, y: 22.2273),
          control1: CGPoint(x: 30.5091, y: 27.8364),
          control2: CGPoint(x: 31.6, y: 25.2727)
        )
        p.closeSubpath()
      }
      context.fill(bluePath.applying(transform), with: .color(Color(red: 66/255, green: 133/255, blue: 244/255)))

      // Green segment - M22 32 C24.7 32 26.9636 31.1045 28.6181 29.5773 L25.3863 27.0682 C24.4909 27.6682 23.3454 28.0227 22 28.0227 C19.3954 28.0227 17.1909 26.2636 16.4045 23.9 H13.0636 V26.4909 C14.7091 29.7591 18.0909 32 22 32 Z
      let greenPath = Path { p in
        p.move(to: CGPoint(x: 22, y: 32))
        p.addCurve(
          to: CGPoint(x: 28.6181, y: 29.5773),
          control1: CGPoint(x: 24.7, y: 32),
          control2: CGPoint(x: 26.9636, y: 31.1045)
        )
        p.addLine(to: CGPoint(x: 25.3863, y: 27.0682))
        p.addCurve(
          to: CGPoint(x: 22, y: 28.0227),
          control1: CGPoint(x: 24.4909, y: 27.6682),
          control2: CGPoint(x: 23.3454, y: 28.0227)
        )
        p.addCurve(
          to: CGPoint(x: 16.4045, y: 23.9),
          control1: CGPoint(x: 19.3954, y: 28.0227),
          control2: CGPoint(x: 17.1909, y: 26.2636)
        )
        p.addLine(to: CGPoint(x: 13.0636, y: 23.9))
        p.addLine(to: CGPoint(x: 13.0636, y: 26.4909))
        p.addCurve(
          to: CGPoint(x: 22, y: 32),
          control1: CGPoint(x: 14.7091, y: 29.7591),
          control2: CGPoint(x: 18.0909, y: 32)
        )
        p.closeSubpath()
      }
      context.fill(greenPath.applying(transform), with: .color(Color(red: 52/255, green: 168/255, blue: 83/255)))

      // Yellow segment - M16.4045 23.9 C16.2045 23.3 16.0909 22.6591 16.0909 22 C16.0909 21.3409 16.2045 20.7 16.4045 20.1 V17.5091 H13.0636 C12.3864 18.8591 12 20.3864 12 22 C12 23.6136 12.3864 25.1409 13.0636 26.4909 L16.4045 23.9 Z
      let yellowPath = Path { p in
        p.move(to: CGPoint(x: 16.4045, y: 23.9))
        p.addCurve(
          to: CGPoint(x: 16.0909, y: 22),
          control1: CGPoint(x: 16.2045, y: 23.3),
          control2: CGPoint(x: 16.0909, y: 22.6591)
        )
        p.addCurve(
          to: CGPoint(x: 16.4045, y: 20.1),
          control1: CGPoint(x: 16.0909, y: 21.3409),
          control2: CGPoint(x: 16.2045, y: 20.7)
        )
        p.addLine(to: CGPoint(x: 16.4045, y: 17.5091))
        p.addLine(to: CGPoint(x: 13.0636, y: 17.5091))
        p.addCurve(
          to: CGPoint(x: 12, y: 22),
          control1: CGPoint(x: 12.3864, y: 18.8591),
          control2: CGPoint(x: 12, y: 20.3864)
        )
        p.addCurve(
          to: CGPoint(x: 13.0636, y: 26.4909),
          control1: CGPoint(x: 12, y: 23.6136),
          control2: CGPoint(x: 12.3864, y: 25.1409)
        )
        p.addLine(to: CGPoint(x: 16.4045, y: 23.9))
        p.closeSubpath()
      }
      context.fill(yellowPath.applying(transform), with: .color(Color(red: 251/255, green: 188/255, blue: 4/255)))

      // Red segment - M22 15.9773 C23.4681 15.9773 24.7863 16.4818 25.8227 17.4727 L28.6909 14.6045 C26.9591 12.9909 24.6954 12 22 12 C18.0909 12 14.7091 14.2409 13.0636 17.5091 L16.4045 20.1 C17.1909 17.7364 19.3954 15.9773 22 15.9773 Z
      let redPath = Path { p in
        p.move(to: CGPoint(x: 22, y: 15.9773))
        p.addCurve(
          to: CGPoint(x: 25.8227, y: 17.4727),
          control1: CGPoint(x: 23.4681, y: 15.9773),
          control2: CGPoint(x: 24.7863, y: 16.4818)
        )
        p.addLine(to: CGPoint(x: 28.6909, y: 14.6045))
        p.addCurve(
          to: CGPoint(x: 22, y: 12),
          control1: CGPoint(x: 26.9591, y: 12.9909),
          control2: CGPoint(x: 24.6954, y: 12)
        )
        p.addCurve(
          to: CGPoint(x: 13.0636, y: 17.5091),
          control1: CGPoint(x: 18.0909, y: 12),
          control2: CGPoint(x: 14.7091, y: 14.2409)
        )
        p.addLine(to: CGPoint(x: 16.4045, y: 20.1))
        p.addCurve(
          to: CGPoint(x: 22, y: 15.9773),
          control1: CGPoint(x: 17.1909, y: 17.7364),
          control2: CGPoint(x: 19.3954, y: 15.9773)
        )
        p.closeSubpath()
      }
      context.fill(redPath.applying(transform), with: .color(Color(red: 234/255, green: 66/255, blue: 53/255)))
    }
    .frame(width: size, height: size)
  }
}

#Preview {
  GoogleGLogo(size: 48)
    .background(Color.white)
}
