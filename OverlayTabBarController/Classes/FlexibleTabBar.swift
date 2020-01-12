import UIKit

open class FlexibleTabBar: UITabBar {
  
  override open var traitCollection: UITraitCollection {
    get {
      if UIDevice.current.userInterfaceIdiom == .pad && UIDevice.current.orientation.isPortrait {
        return UITraitCollection(horizontalSizeClass: .compact)
      }
      return super.traitCollection
    }
  }
  
}
