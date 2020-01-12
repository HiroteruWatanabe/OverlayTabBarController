import UIKit

class SampleOverlayViewController: UIViewController {
  static func make() -> SampleOverlayViewController {
    return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "SampleOverlayViewController")
  }
}
