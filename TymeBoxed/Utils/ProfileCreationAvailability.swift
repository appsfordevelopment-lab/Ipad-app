import UIKit

/// iPad is treated as a companion to iPhone; profiles are created on iPhone and synced via iCloud.
enum ProfileCreationAvailability {
  static var allowsLocalProfileCreation: Bool {
    UIDevice.current.userInterfaceIdiom != .pad
  }
}
