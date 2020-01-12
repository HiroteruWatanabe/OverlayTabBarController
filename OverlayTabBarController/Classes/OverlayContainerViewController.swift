import UIKit

public protocol UIViewControllerOverlay {
  var gestureResponder: UIView { get }
  
  func didStartTransitionTo(state: OverlayContainerViewController.OverlayViewState, fractionComplete: CGFloat, animationDuration: TimeInterval)
  func didEndTransitionTo(state: OverlayContainerViewController.OverlayViewState, fractionComplete: CGFloat, animationThreshold: CGFloat)
  func didUpdateTransition(fractionComplete: CGFloat)
  func continueTransition(fractionComplete: CGFloat, animationThreshold: CGFloat)
}

open class OverlayContainerViewController: UIViewController {
  public typealias OverlayViewController = UIViewController & UIViewControllerOverlay
  
  public enum OverlayViewState {
      case collapsed
      case expanded
  }

  
  public var isOverlayViewExpanded: Bool = false
  public var animationThreshold: CGFloat = 0.1
  public private(set) var animationProgressWhenInterrupted: CGFloat = 0.0
  public var transitionDuration: TimeInterval = 0.3
  
  public var animations: [UIViewPropertyAnimator] = []
  public var dimmedView: UIView!
  public var overlayViewController: OverlayViewController?
  public var overlayViewCollapsedHeight: CGFloat = 44
  public var overlayViewExpandedHeight: CGFloat = 400
  public var overlayViewExpandedConstraint: NSLayoutConstraint?
  public var overlayViewCollapsedConstraint: NSLayoutConstraint?
  public private(set) var expandedViewCornerRadius: CGFloat = 8
  
  public var isOverlayViewPresented: Bool {
    return overlayViewController != nil
  }
  
  public var overlayViewCornerRadius: CGFloat {
    return isOverlayViewExpanded ? overlayViewExpandedCornerRadius : overlayViewCollapsedCornerRadius
  }
  
  public var overlayViewCollapsedCornerRadius: CGFloat = 18 {
    didSet {
      updateOverlayViewCornerRadius()
    }
  }
  public var overlayViewExpandedCornerRadius: CGFloat = 5 {
    didSet {
      updateOverlayViewCornerRadius()
    }
  }
  
  public var butterflyHandle: ButterflyHandle?
  public var hidesPreviewingViewWhenExpanded: Bool = true
  public var gestureResponder: UIView?
  
  public var isOverlayViewShadowHidden: Bool = false {
    didSet {
      setupOverlayViewShadow()
    }
  }
  
  open func setupOverlayViewShadow() {
    guard !isOverlayViewShadowHidden else {
      overlayViewController?.view.layer.shadowOpacity = 0
      return
    }
    guard let cardViewController = overlayViewController else { return }
    cardViewController.view.layer.shadowColor = UIColor.black.cgColor
    cardViewController.view.layer.shadowOffset = .zero
    cardViewController.view.layer.shadowRadius = 3
    cardViewController.view.layer.shadowOpacity = 0.25
    cardViewController.view.layer.masksToBounds = false
  }
  
  open func setOverlayViewController(_ overlayViewController: OverlayViewController) {
    setOverlayViewController(overlayViewController, collapsedHeight: 44, expandedHeight: 400)
  }
  
  open func setOverlayViewController(_ overlayViewController: OverlayViewController, collapsedHeight: CGFloat, expandedHeight: CGFloat) {
    overlayViewCollapsedHeight = collapsedHeight
    overlayViewExpandedHeight = expandedHeight
    
    self.overlayViewController = overlayViewController
    overlayViewController.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    overlayViewController.view.layer.masksToBounds = true
    overlayViewController.view.layer.cornerRadius = overlayViewCornerRadius
    
    addChild(overlayViewController)
    
    let butterflyHandle = ButterflyHandle()
    self.butterflyHandle = butterflyHandle
    
    butterflyHandle.widthAnchor.constraint(equalToConstant: butterflyHandle.frame.width).isActive = true
    butterflyHandle.heightAnchor.constraint(equalToConstant: butterflyHandle.frame.height).isActive = true
    butterflyHandle.translatesAutoresizingMaskIntoConstraints = false
    overlayViewController.view.addSubview(butterflyHandle)
    butterflyHandle.topAnchor.constraint(equalTo: overlayViewController.view.topAnchor, constant: 8).isActive = true
    butterflyHandle.centerXAnchor.constraint(equalTo: overlayViewController.view.centerXAnchor).isActive = true
    butterflyHandle.setSelected(true, animated: false)
    
    view.addSubview(overlayViewController.view)
    overlayViewController.view.translatesAutoresizingMaskIntoConstraints = false
    overlayViewController.view.heightAnchor.constraint(equalToConstant: overlayViewExpandedHeight).isActive = true
    overlayViewCollapsedConstraint = overlayViewController.view.topAnchor.constraint(equalTo: view.bottomAnchor, constant: -overlayViewCollapsedHeight)
    overlayViewExpandedConstraint = overlayViewController.view.topAnchor.constraint(equalTo: view.bottomAnchor, constant: -overlayViewExpandedHeight)
    
    overlayViewCollapsedConstraint?.isActive = true
    overlayViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
    overlayViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    
    overlayViewController.didMove(toParent: self)
    
    let gestureResponder = overlayViewController.gestureResponder
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGestrue(gestureRecognizer:)))
    gestureResponder.addGestureRecognizer(tapGestureRecognizer)
    let panGetstureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(gestureRecognizer:)))
    gestureResponder.addGestureRecognizer(panGetstureRecognizer)
    
    setupOverlayViewShadow()
  }
  
  open func removeOverlayViewController(animated: Bool, completion: (() -> ())? = nil) {
    if isOverlayViewExpanded {
      transitionIfNeededTo(state: .collapsed, duration: animated ? transitionDuration : 0) { [weak self] in
        self?.overlayViewController?.willMove(toParent: nil)
        self?.overlayViewController?.view.removeFromSuperview()
        self?.overlayViewController?.removeFromParent()
        self?.overlayViewController = nil
        self?.butterflyHandle?.removeFromSuperview()
        completion?()
      }
    } else {
      overlayViewController?.willMove(toParent: nil)
      overlayViewController?.view.removeFromSuperview()
      overlayViewController?.removeFromParent()
      overlayViewController = nil
      butterflyHandle?.removeFromSuperview()
      completion?()
    }
  }
  
  public func updateOverlayViewCornerRadius() {
    guard let overlayView = overlayViewController?.view else { return }
    overlayView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    overlayView.layer.masksToBounds = true
    overlayView.layer.cornerRadius = overlayViewCornerRadius
  }
  
  
  @objc public func handleTapGestrue(gestureRecognizer: UITapGestureRecognizer) {
    overlayViewController?.didStartTransitionTo(state: isOverlayViewExpanded ? .collapsed : .expanded, fractionComplete: 0, animationDuration: transitionDuration)
    transitionIfNeededTo(state: isOverlayViewExpanded ? .collapsed : .expanded, duration: transitionDuration)
  }
  
  @objc public func handlePanGesture(gestureRecognizer: UIPanGestureRecognizer) {
    let translation = gestureRecognizer.translation(in: overlayViewController?.view)
    var fractionComplete = translation.y / (overlayViewExpandedHeight - overlayViewCollapsedHeight)
    fractionComplete = max(min(abs(fractionComplete), 1), 0)
    switch gestureRecognizer.state {
    case .began:
      startTransitionTo(state: isOverlayViewExpanded ? .collapsed : .expanded, duration: transitionDuration)
    case .changed:
      updateTransition(fractionComplete: fractionComplete)
    case .ended:
      continueTransition(fractionComplete: fractionComplete)
    default:
      break
    }
  }
  
  open func collapseCardViewController(animated: Bool) {
    guard isOverlayViewExpanded else { return }
    overlayViewController?.didStartTransitionTo(state: .collapsed, fractionComplete: 0, animationDuration: animated ? transitionDuration : 0)
    transitionIfNeededTo(state: .collapsed, duration: animated ? transitionDuration : 0)
  }
  
  open func startTransitionTo(state: OverlayViewState, duration: TimeInterval) {
    if animations.isEmpty {
      transitionIfNeededTo(state: state, duration: duration)
    }
    animations.forEach({
      $0.pauseAnimation()
      animationProgressWhenInterrupted = $0.fractionComplete
    })
    overlayViewController?.didStartTransitionTo(state: state, fractionComplete: isOverlayViewExpanded ? 1.0 : 0, animationDuration: duration)
  }
  
  open func updateTransition(fractionComplete: CGFloat) {
    animations.forEach({
      $0.fractionComplete = fractionComplete + animationProgressWhenInterrupted
    })
    overlayViewController?.didUpdateTransition(fractionComplete: fractionComplete + animationProgressWhenInterrupted)
  }
  
  open func continueTransition(fractionComplete: CGFloat) {
    animations.forEach({
      $0.isReversed = fractionComplete <= animationThreshold
      $0.continueAnimation(withTimingParameters: nil, durationFactor: 0)
    })
    
    overlayViewController?.continueTransition(fractionComplete: fractionComplete, animationThreshold: animationThreshold)
  }
  
  open func transitionIfNeededTo(state: OverlayViewState, duration: TimeInterval, completion: (() -> ())? = nil) {
    guard animations.isEmpty else { return }
    
    animations = []
    
    switch state {
    case .expanded:
      overlayViewCollapsedConstraint?.isActive = false
      overlayViewExpandedConstraint?.isActive = true
    case .collapsed:
      overlayViewExpandedConstraint?.isActive = false
      overlayViewCollapsedConstraint?.isActive = true
    }
    
    let frameAnimator = UIViewPropertyAnimator(duration: duration, curve: .linear) {
      switch state {
      case .expanded:
        self.overlayViewController?.view.layer.cornerRadius = self.overlayViewExpandedCornerRadius
      case .collapsed:
        self.overlayViewController?.view.layer.cornerRadius = self.overlayViewCollapsedCornerRadius
      }
      self.view.layoutIfNeeded()
    }
    frameAnimator.addCompletion { (position) in
      switch state {
      case .expanded:
        self.isOverlayViewExpanded = position == .end
      case .collapsed:
        self.isOverlayViewExpanded = position == .start
      }
      self.animations.removeAll()
      
      if self.isOverlayViewExpanded {
        self.overlayViewCollapsedConstraint?.isActive = false
        self.overlayViewExpandedConstraint?.isActive = true
      } else {
        self.overlayViewExpandedConstraint?.isActive = false
        self.overlayViewCollapsedConstraint?.isActive = true
      }
      
      self.overlayViewController?.didEndTransitionTo(state: state, fractionComplete: self.isOverlayViewExpanded ? 1.0 : 0.0, animationThreshold: self.animationThreshold)
      completion?()
    }
    frameAnimator.startAnimation()
    animations.append(frameAnimator)
  }
}
