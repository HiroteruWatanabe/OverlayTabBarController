import UIKit
import OverlayTabBarController

class SampleOverlayTabBarController: OverlayTabBarController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    let overlayViewController = SampleOverlayViewController.make()
    overlayViewMaximumHeight = 896
    let previewingViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "PreviewingViewController")
    setOverlayViewController(overlayViewController, previewingViewController: previewingViewController, isExpanded: false, animated: true)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
}

