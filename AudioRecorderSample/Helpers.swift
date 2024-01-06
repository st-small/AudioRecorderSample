import Foundation

let dateComponentsFormatter: DateComponentsFormatter = {
  let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
  formatter.zeroFormattingBehavior = .pad
  return formatter
}()
