import UIKit

open class OverlayTabBarController: UITabBarController {
  public enum OverlayViewState {
    case collapsed
    case expanded
  }
  
  override open var viewControllers: [UIViewController]? {
    set {
      guard let overlayViewController = overlayViewController,
        let previewingViewController = previewingViewController else {
          super.viewControllers = newValue
          return
      }
      super.viewControllers = newValue?.filter({ $0 != overlayViewController && $0 != previewingViewController })
    }
    get {
      guard let overlayViewController = overlayViewController, let previewingViewController = previewingViewController else { return super.viewControllers }
      return super.viewControllers?.filter({ $0 != overlayViewController && $0 != previewingViewController })
    }
  }
  
  public var isOverlayViewExpanded: Bool = false {
    didSet {
      gestureResponder?.isUserInteractionEnabled = isOverlayViewExpanded
    }
  }
  private var animationThreshold: CGFloat = 0.1
  private var animationProgressWhenInterrupted: CGFloat = 0.0
  private var transitionDuration: TimeInterval = 0.3
  
  private var animations: [UIViewPropertyAnimator] = []
  private var dimmedView: UIView!
  private var overlayViewExpandedConstraints = LayoutConstraintGroup()
  private var overlayViewCollapsedConstraints = LayoutConstraintGroup()
  public var isOverlayViewPresented: Bool {
    return overlayViewController != nil
  }
  public var overlayViewController: UIViewController?
  public var previewingViewController: UIViewController?

  public var butterflyHandle: ButterflyHandle?
  public var hidesButterflyHandleWhenCollapsed: Bool = false {
    didSet {
      guard !isOverlayViewExpanded else { return }
      butterflyHandle?.alpha = hidesButterflyHandleWhenCollapsed ? 0 : 1
    }
  }
  private var longPressGestureStartPoint: CGPoint = .zero
  public var hidesPreviewingViewWhenExpanded: Bool = true
  public var gestureResponder: UIView?
  public var previewingViewHeightWhenHorizontalSizeClassCompact: CGFloat = 56
  public var previewingViewHeight: CGFloat {
    if isHorizontalSizeClassRegular {
      return tabBar.frame.height
    } else {
      return previewingViewHeightWhenHorizontalSizeClassCompact
    }
  }
  
  // MARK: Properties TabBar
  public var flexibleTabBar: FlexibleTabBar!
  public var flexibleTabBarWidthWhenHorizontalSizeClassRegular: CGFloat = 375 {
    didSet {
      guard isHorizontalSizeClassRegular else { return }
      guard flexibleTabBarWidthWhenHorizontalSizeClassRegular != oldValue else { return }
      updateFlexibleTabBarConstraints()
    }
  }
  private var flexibleTabBarConstraintGroup: LayoutConstraintGroup = LayoutConstraintGroup()
  private var flexibleTabBarExpandedConstraintGroup: LayoutConstraintGroup = LayoutConstraintGroup()
  private var flexibleTabBarCollapsedConstraintGroup: LayoutConstraintGroup = LayoutConstraintGroup()
  
  public var previewingTabBar: UITabBar!
  private var previewingTabBarBottomConstraint: NSLayoutConstraint?
  private var previewingTabBarConstraints: LayoutConstraintGroup = LayoutConstraintGroup()
  
  var isHorizontalSizeClassRegular: Bool {
    return traitCollection.horizontalSizeClass == .regular
  }

  override open func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    
    setupDimmedView()
    setupFlexibleTabBar()
  }
  
  override open func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    guard tabBar == flexibleTabBar else { return }
    guard let items = tabBar.items else { return }
    for i in 0..<items.count {
      if items[i].tag == item.tag {
        selectedIndex = i
        return
      }
    }
  }
  
  override open func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool) {
    super.setViewControllers(viewControllers, animated: animated)
    updateFlexibleTabBarItems()
  }
  
  override open func addChild(_ childController: UIViewController) {
    let viewControllers = self.viewControllers
    super.addChild(childController)
    if childController == overlayViewController || childController == previewingViewController {
      self.viewControllers = viewControllers
    }
  }
  
  override open func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    super.willTransition(to: newCollection, with: coordinator)
    if traitCollection.horizontalSizeClass != newCollection.horizontalSizeClass {
      guard overlayViewController != nil else { return }
      temporaryRemoveOverlayViewController()
      setupButterflyHandle()
      setupGestureResponder()
    }
  }
  
  override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    
    if let previewView = previewingViewController?.view {
      previewView.setNeedsLayout()
    }
    
    if previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass {
      setupFlexibleTabBar()
      if let overlayViewController = overlayViewController, let previewViewController = previewingViewController {
        setOverlayViewController(overlayViewController, previewingViewController: previewViewController, isExpanded: isOverlayViewExpanded, animated: false)
        updateView()
      }
    }
    
    view.setNeedsLayout()
  }
  
  private func setupDimmedView() {
    dimmedView = UIView()
    view.addSubview(dimmedView)
    dimmedView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    dimmedView.translatesAutoresizingMaskIntoConstraints = false
    dimmedView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    dimmedView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
    dimmedView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    dimmedView.bottomAnchor.constraint(equalTo: tabBar.topAnchor).isActive = true
    dimmedView.alpha = isOverlayViewExpanded ? 1.0 : 0
    
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDimmedViewTapGesture(gestureRecognizer:)))
    dimmedView.addGestureRecognizer(tapGestureRecognizer)
  }
  
  @objc private func handleDimmedViewTapGesture(gestureRecognizer: UITapGestureRecognizer) {
    collapseOverlayViewController(animated: true)
  }
  
  private func setupPreviewingTabBar() {
    if let previewingTabBar = self.previewingTabBar {
      previewingTabBar.removeFromSuperview()
    }
    let previewingTabBar = UITabBar()
    self.previewingTabBar = previewingTabBar
    previewingTabBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(previewingTabBar)
    
    previewingTabBar.barStyle = tabBar.barStyle
    previewingTabBar.isTranslucent = tabBar.isTranslucent
    previewingTabBarConstraints.isActive = false
    previewingTabBar.removeConstraints(previewingTabBarConstraints.constraints)
    previewingTabBarConstraints.removeAll()
    previewingTabBarBottomConstraint = nil
    
    if isHorizontalSizeClassRegular {
      let leadingConstraint = previewingTabBar.leadingAnchor.constraint(equalTo: flexibleTabBar.trailingAnchor)
      previewingTabBarConstraints.append(leadingConstraint)
      leadingConstraint.isActive = true
      
      let topConstraint = previewingTabBar.topAnchor.constraint(equalTo: flexibleTabBar.topAnchor)
      topConstraint.isActive = true
      previewingTabBarConstraints.append(topConstraint)
      
      let bottomConstraint = previewingTabBar.bottomAnchor.constraint(equalTo: flexibleTabBar.bottomAnchor)
      previewingTabBarConstraints.append(bottomConstraint)
      bottomConstraint.isActive = true
      
      let trailingConstraint = previewingTabBar.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor)
      previewingTabBarConstraints.append(trailingConstraint)
      trailingConstraint.isActive = true
      previewingTabBar.isHidden = false
    } else {
      let leadingConstraint = previewingTabBar.leadingAnchor.constraint(equalTo: flexibleTabBar.leadingAnchor)
      previewingTabBarConstraints.append(leadingConstraint)
      leadingConstraint.isActive = true
      
      let trailingConstraint = previewingTabBar.trailingAnchor.constraint(equalTo: flexibleTabBar.trailingAnchor)
      previewingTabBarConstraints.append(trailingConstraint)
      trailingConstraint.isActive = true
      
      let bottomConstraint = previewingTabBar.bottomAnchor.constraint(equalTo: flexibleTabBar.topAnchor)
      bottomConstraint.isActive = true
      previewingTabBarBottomConstraint = bottomConstraint
      previewingTabBarConstraints.append(bottomConstraint)
      
      let heightConstraint = previewingTabBar.heightAnchor.constraint(equalToConstant: previewingViewHeight)
      heightConstraint.isActive = true
      previewingTabBarConstraints.append(heightConstraint)
      
      previewingTabBar.isHidden = overlayViewController == nil
    }
  }
  
  private func setupFlexibleTabBar() {
    tabBar.isHidden = true
    if let flexibleTabbar = flexibleTabBar {
      flexibleTabbar.removeFromSuperview()
    }
    
    flexibleTabBar = FlexibleTabBar()
    flexibleTabBar.barStyle = tabBar.barStyle
    flexibleTabBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(flexibleTabBar)
    updateFlexibleTabBarConstraints()
    updateFlexibleTabBarItems()
    setupPreviewingTabBar()
  }
  
  private func updateFlexibleTabBarConstraints() {
    guard let flexibleTabBar = self.flexibleTabBar else { return }
    flexibleTabBarConstraintGroup.isActive = false
    flexibleTabBarExpandedConstraintGroup.isActive = false
    flexibleTabBarCollapsedConstraintGroup.isActive = false
    flexibleTabBar.removeConstraints(flexibleTabBarConstraintGroup.constraints)
    flexibleTabBarConstraintGroup.removeAll()
    flexibleTabBarExpandedConstraintGroup.removeAll()
    flexibleTabBarCollapsedConstraintGroup.removeAll()
    
    let leadingConstraint = flexibleTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor)
    flexibleTabBarConstraintGroup.append(leadingConstraint)
    leadingConstraint.isActive = true
    
    let collapsedTopConstraint = flexibleTabBar.topAnchor.constraint(equalTo: tabBar.topAnchor)
    flexibleTabBarConstraintGroup.append(collapsedTopConstraint)
    flexibleTabBarCollapsedConstraintGroup.append(collapsedTopConstraint)
    
    let collapsedBottomConstraint = flexibleTabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    flexibleTabBarConstraintGroup.append(collapsedBottomConstraint)
    flexibleTabBarCollapsedConstraintGroup.append(collapsedBottomConstraint)
    
    if isHorizontalSizeClassRegular {
      let expandedTopConstraint = flexibleTabBar.topAnchor.constraint(equalTo: tabBar.topAnchor)
      flexibleTabBarConstraintGroup.append(expandedTopConstraint)
      flexibleTabBarExpandedConstraintGroup.append(expandedTopConstraint)
      
      let expandedBottomConstraint = flexibleTabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
      flexibleTabBarConstraintGroup.append(expandedBottomConstraint)
      flexibleTabBarExpandedConstraintGroup.append(expandedBottomConstraint)
    } else {
      let expandedTopConstraint = flexibleTabBar.topAnchor.constraint(equalTo: view.bottomAnchor)
      flexibleTabBarConstraintGroup.append(expandedTopConstraint)
      flexibleTabBarExpandedConstraintGroup.append(expandedTopConstraint)
      let expandedHeightConstraint = flexibleTabBar.heightAnchor.constraint(equalToConstant: tabBar.frame.height)
      flexibleTabBarConstraintGroup.append(expandedHeightConstraint)
      flexibleTabBarExpandedConstraintGroup.append(expandedHeightConstraint)
    }
    
    flexibleTabBar.delegate = self
    
    if isHorizontalSizeClassRegular {
      let widthConstraint = flexibleTabBar.widthAnchor.constraint(equalTo: tabBar.widthAnchor, constant: -flexibleTabBarWidthWhenHorizontalSizeClassRegular)
      flexibleTabBarConstraintGroup.append(widthConstraint)
      widthConstraint.isActive = true
      drawTabBarBorder()
    } else {
      let widthConstraint = flexibleTabBar.widthAnchor.constraint(equalTo: tabBar.widthAnchor, constant: 0)
      flexibleTabBarConstraintGroup.append(widthConstraint)
      widthConstraint.isActive = true
    }
    
    if isOverlayViewExpanded {
      flexibleTabBarExpandedConstraintGroup.isActive = true
    } else {
      flexibleTabBarCollapsedConstraintGroup.isActive = true
    }
  }
  
  private func drawTabBarBorder() {
    let border = UIView()
    border.backgroundColor = UIColor(white: 0.57, alpha: 0.85)
    border.translatesAutoresizingMaskIntoConstraints = false
    flexibleTabBar.addSubview(border)
    border.trailingAnchor.constraint(equalTo: flexibleTabBar.trailingAnchor).isActive = true
    border.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
    border.topAnchor.constraint(equalTo: flexibleTabBar.topAnchor, constant: 4).isActive = true
    border.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0).isActive = true
  }
  
  private func updateFlexibleTabBarItems() {
    var itemsForFlexibleTabBar: [UITabBarItem] = []
    for (index, item) in (tabBar.items ?? []).enumerated() {
      guard (viewControllers?.count ?? 0) > index else { break }
      guard viewControllers?[index] != overlayViewController else { continue }
      item.tag = index
      let title = item.title
      let image = item.image?.copy() as? UIImage
      let tag = item.tag
      let flexibleItem = UITabBarItem(title: title, image: image, tag: tag)
      flexibleItem.selectedImage = item.selectedImage?.copy() as? UIImage
      itemsForFlexibleTabBar.append(flexibleItem)
    }
    flexibleTabBar.setItems(itemsForFlexibleTabBar, animated: false)
    
    if (flexibleTabBar.items?.count ?? 0) > selectedIndex {
      flexibleTabBar.selectedItem = flexibleTabBar.items?[selectedIndex]
    } else {
      flexibleTabBar.selectedItem = flexibleTabBar.items?.first
    }
  }

  open func setOverlayViewController(_ overlayViewController: UIViewController, previewingViewController: UIViewController, isExpanded: Bool, animated: Bool = true) {
    self.previewingViewController = previewingViewController
    self.overlayViewController = overlayViewController
    addChild(previewingViewController)
    if isHorizontalSizeClassRegular {
      addChild(overlayViewController)
      setOverrideTraitCollection(UITraitCollection(traitsFrom: [UITraitCollection(horizontalSizeClass: .regular), UITraitCollection(verticalSizeClass: .regular)]), forChild: previewingViewController)
      setOverrideTraitCollection(UITraitCollection(traitsFrom: [UITraitCollection(horizontalSizeClass: .regular), UITraitCollection(verticalSizeClass: .regular)]), forChild: overlayViewController)
    } else {
      setOverrideTraitCollection(UITraitCollection(traitsFrom: [UITraitCollection(horizontalSizeClass: .compact), UITraitCollection(verticalSizeClass: .regular)]), forChild: previewingViewController)
      setOverrideTraitCollection(UITraitCollection(traitsFrom: [UITraitCollection(horizontalSizeClass: .regular), UITraitCollection(verticalSizeClass: .regular)]), forChild: overlayViewController)
    }
    
    isOverlayViewExpanded = isExpanded
    setupPreviewingTabBar()
    
    setupButterflyHandle()
    
    previewingTabBar.addSubview(previewingViewController.view)
    view.addSubview(overlayViewController.view)
    overlayViewController.view.isHidden = !isExpanded
    setupOverlayViewConstraints()

    previewingViewController.didMove(toParent: self)
    if isHorizontalSizeClassRegular {
      overlayViewController.didMove(toParent: self)
    } else if isExpanded {
      presentOverlayViewController(animated: animated, completion: nil)
    }
    setupGestureRecognizers(view: previewingViewController.view)
    setupGestureResponder()
    gestureResponder?.isUserInteractionEnabled = isOverlayViewExpanded
    
    view.bringSubviewToFront(flexibleTabBar)
  }
  
  private func setupOverlayViewConstraints() {
    guard let overlayViewController = overlayViewController else { return }
    guard let previewViewController = previewingViewController else { return }
    overlayViewExpandedConstraints.isActive = false
    overlayViewCollapsedConstraints.isActive = false
    overlayViewController.view.translatesAutoresizingMaskIntoConstraints = false
    overlayViewController.view.leadingAnchor.constraint(equalTo: previewingTabBar.leadingAnchor).isActive = true
    overlayViewController.view.trailingAnchor.constraint(equalTo: previewingTabBar.trailingAnchor).isActive = true
    
    let collapsedTopConstraint = overlayViewController.view.topAnchor.constraint(equalTo: previewingTabBar.topAnchor)
    let collapsedHeightConstraint = overlayViewController.view.heightAnchor.constraint(equalToConstant: overlayViewController.view.frame.height)
    overlayViewCollapsedConstraints.removeAll()
    overlayViewCollapsedConstraints.append(collapsedTopConstraint)
    overlayViewCollapsedConstraints.append(collapsedHeightConstraint)
    let expandedTopConstraint = overlayViewController.view.topAnchor.constraint(equalTo: view.topAnchor)
    let expandedBottomConstraint = overlayViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    overlayViewExpandedConstraints.removeAll()
    overlayViewExpandedConstraints.append(expandedTopConstraint)
    overlayViewExpandedConstraints.append(expandedBottomConstraint)
    
    if isOverlayViewExpanded {
      overlayViewExpandedConstraints.isActive = true
    } else {
      overlayViewCollapsedConstraints.isActive = true
    }
    
    previewViewController.view.translatesAutoresizingMaskIntoConstraints = false
    previewViewController.view.leadingAnchor.constraint(equalTo: previewingTabBar.leadingAnchor).isActive = true
    previewViewController.view.trailingAnchor.constraint(equalTo: previewingTabBar.trailingAnchor).isActive = true
    previewViewController.view.topAnchor.constraint(equalTo: previewingTabBar.topAnchor).isActive = true
    previewViewController.view.bottomAnchor.constraint(equalTo: previewingTabBar.bottomAnchor).isActive = true
  }
  
  private func setupButterflyHandle() {
    guard let overlayViewController = overlayViewController else { return }
    self.butterflyHandle?.removeFromSuperview()
    let butterflyHandle = ButterflyHandle()
    self.butterflyHandle = butterflyHandle
    butterflyHandle.widthAnchor.constraint(equalToConstant: butterflyHandle.frame.width).isActive = true
    butterflyHandle.heightAnchor.constraint(equalToConstant: butterflyHandle.frame.height).isActive = true
    butterflyHandle.translatesAutoresizingMaskIntoConstraints = false
    overlayViewController.view.addSubview(butterflyHandle)
    butterflyHandle.topAnchor.constraint(equalTo: overlayViewController.view.topAnchor, constant: 8).isActive = true
    butterflyHandle.centerXAnchor.constraint(equalTo: overlayViewController.view.centerXAnchor).isActive = true
    
    butterflyHandle.setSelected(true, animated: false)
    if hidesButterflyHandleWhenCollapsed, !isOverlayViewExpanded {
      butterflyHandle.alpha = 0
    } else {
      butterflyHandle.alpha = 1
    }
  }
  
  private func setupGestureResponder() {
    guard let overlayViewController = overlayViewController else { return }
    guard let previewingView = previewingViewController?.view else { return }
    self.gestureResponder?.removeFromSuperview()
    let gestureResponder = UIView()
    self.gestureResponder = gestureResponder
    gestureResponder.translatesAutoresizingMaskIntoConstraints = false
    overlayViewController.view.insertSubview(gestureResponder, belowSubview: previewingView)
    gestureResponder.topAnchor.constraint(equalTo: overlayViewController.view.topAnchor).isActive = true
    gestureResponder.leadingAnchor.constraint(equalTo: overlayViewController.view.leadingAnchor).isActive = true
    gestureResponder.trailingAnchor.constraint(equalTo: overlayViewController.view.trailingAnchor).isActive = true
    gestureResponder.heightAnchor.constraint(equalToConstant: 66).isActive = true
    
    setupGestureRecognizers(view: gestureResponder)
  }
  
  private func temporaryRemoveOverlayViewController() {
    if isHorizontalSizeClassRegular {
      overlayViewController?.view.removeFromSuperview()
    } else {
      overlayViewController?.dismiss(animated: false, completion: nil)
    }
  }
  
  open func removeOverlayViewController(animated: Bool, completion: (() -> ())? = nil) {
    if isOverlayViewExpanded {
      transitionIfNeededTo(state: .collapsed, duration: animated ? transitionDuration : 0) { [weak self] in
        self?.overlayViewController?.willMove(toParent: nil)
        self?.overlayViewController?.view.removeFromSuperview()
        self?.overlayViewController?.removeFromParent()
        self?.overlayViewController = nil
        self?.butterflyHandle?.removeFromSuperview()
        if self?.isHorizontalSizeClassRegular == false {
          self?.previewingTabBar.isHidden = true
        }
        completion?()
      }
    } else {
      overlayViewController?.willMove(toParent: nil)
      overlayViewController?.view.removeFromSuperview()
      overlayViewController?.removeFromParent()
      overlayViewController = nil
      butterflyHandle?.removeFromSuperview()
      if !isHorizontalSizeClassRegular {
        previewingTabBar.isHidden = true
      }
      completion?()
    }
  }
  
  private func setupGestureRecognizers(view: UIView) {
    view.gestureRecognizers?.forEach({ view.removeGestureRecognizer($0) })
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGestrue(gestureRecognizer:)))
    view.addGestureRecognizer(tapGestureRecognizer)
    
    let panGetstureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(gestureRecognizer:)))
    view.addGestureRecognizer(panGetstureRecognizer)
    
    let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(gestureRecognizer:)))
    view.addGestureRecognizer(longPressGestureRecognizer)
  }
  
  @objc open func handleTapGestrue(gestureRecognizer: UITapGestureRecognizer) {
    butterflyHandle?.setSelected(true, animated: false)
    transitionIfNeededTo(state: isOverlayViewExpanded ? .collapsed : .expanded, duration: transitionDuration)
  }
  
  @objc open func handlePanGesture(gestureRecognizer: UIPanGestureRecognizer) {
    let translation = gestureRecognizer.translation(in: previewingViewController?.view)
    var fractionComplete = translation.y / (view.bounds.height - previewingViewHeight)
    fractionComplete = abs(fractionComplete)
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
  
  @objc open func handleLongPressGesture(gestureRecognizer: UILongPressGestureRecognizer) {
    let location = gestureRecognizer.location(in: view)
    let translation = CGPoint(x: location.x - longPressGestureStartPoint.x, y: location.y - longPressGestureStartPoint.y)
    var fractionComplete = translation.y / (view.bounds.height - previewingViewHeight)
    fractionComplete = abs(fractionComplete)
    switch gestureRecognizer.state {
    case .began:
      longPressGestureStartPoint = gestureRecognizer.location(in: view)
      startTransitionTo(state: isOverlayViewExpanded ? .collapsed : .expanded, duration: transitionDuration)
      updateTransition(fractionComplete: 0)
    case .changed:
      updateTransition(fractionComplete: fractionComplete)
    case .ended:
      continueTransition(fractionComplete: fractionComplete)
    default:
      break
    }
  }
  
  open func collapseOverlayViewController(animated: Bool) {
    guard isOverlayViewExpanded else { return }
    transitionIfNeededTo(state: .collapsed, duration: animated ? transitionDuration : 0)
  }
  
  open func expandOverlayViewController(animated: Bool) {
    guard !isOverlayViewExpanded else { return }
    butterflyHandle?.setSelected(true, animated: false)
    transitionIfNeededTo(state: .expanded, duration: animated ? transitionDuration : 0)
  }
  
  open func startTransitionTo(state: OverlayViewState, duration: TimeInterval) {
    if animations.isEmpty {
      transitionIfNeededTo(state: state, duration: duration)
    }
    animations.forEach({
      $0.pauseAnimation()
      animationProgressWhenInterrupted = $0.fractionComplete
    })
  }
  
  open func updateTransition(fractionComplete: CGFloat) {
    animations.forEach({
      $0.fractionComplete = fractionComplete + animationProgressWhenInterrupted
    })
  }
  
  open func continueTransition(fractionComplete: CGFloat) {
    animations.forEach({
      $0.isReversed = fractionComplete <= animationThreshold
      $0.continueAnimation(withTimingParameters: nil, durationFactor: 0)
    })
  }
  
  private func updateView() {
    if isOverlayViewExpanded {
      butterflyHandle?.alpha = 1
      dimmedView.alpha = 1.0
      if isHorizontalSizeClassRegular {
        flexibleTabBar.alpha = 1
      } else {
        flexibleTabBar.alpha = 0
      }
    } else {
      previewingViewController?.view.alpha = 1
      if hidesButterflyHandleWhenCollapsed {
        butterflyHandle?.alpha = 0
      }
      dimmedView.alpha = 0
      if isHorizontalSizeClassRegular {
        flexibleTabBar.alpha = 1
      } else {
        flexibleTabBar.alpha = 1
      }
    }
  }
  
  open func transitionIfNeededTo(state: OverlayViewState, duration: TimeInterval, completion: (() -> ())? = nil) {
    guard let overlayViewController = overlayViewController else { return }
    if isHorizontalSizeClassRegular {
      guard animations.isEmpty else { return }
      
      animations = []
      let frameAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
        switch state {
        case .expanded:
          self.overlayViewCollapsedConstraints.isActive = false
          self.overlayViewExpandedConstraints.isActive = true
          overlayViewController.view.isHidden = false
          self.view.bringSubviewToFront(overlayViewController.view)
          self.butterflyHandle?.alpha = 1
          self.view.layoutIfNeeded()
        case .collapsed:
          self.overlayViewExpandedConstraints.isActive = false
          self.overlayViewCollapsedConstraints.isActive = true
          if self.hidesButterflyHandleWhenCollapsed {
            self.butterflyHandle?.alpha = 0
          }
          self.view.layoutIfNeeded()
        }
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
          self.overlayViewCollapsedConstraints.isActive = false
          self.overlayViewExpandedConstraints.isActive = true
        } else {
          self.overlayViewExpandedConstraints.isActive = false
          self.overlayViewCollapsedConstraints.isActive = true
          overlayViewController.view.isHidden = true
        }
        completion?()
      }
      frameAnimator.startAnimation()
      animations.append(frameAnimator)
      
      let dimmedViewAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
        switch state {
        case .expanded:
          self.dimmedView.alpha = 1.0
        case .collapsed:
          self.dimmedView.alpha = 0
        }
      }
      dimmedViewAnimator.startAnimation()
      animations.append(dimmedViewAnimator)
    } else {
      switch state {
      case .collapsed:
        dismissOverlayViewController(animated: true, completion: completion)
      case .expanded:
        presentOverlayViewController(animated: true, completion: completion)
      }
      
    }
  }
  
  private func presentOverlayViewController(animated: Bool, completion: (() -> ())?) {
    overlayViewExpandedConstraints.isActive = false
    overlayViewCollapsedConstraints.isActive = false
    overlayViewController?.view.translatesAutoresizingMaskIntoConstraints = true
    guard let overlayViewController = overlayViewController else { return }
    if overlayViewController.parent != nil {
      overlayViewController.removeFromParent()
    }
    overlayViewController.view.isHidden = false
    overlayViewController.modalPresentationStyle = .pageSheet
    overlayViewController.presentationController?.delegate = self
    present(overlayViewController, animated: animated, completion: { [weak self] in
      self?.isOverlayViewExpanded = true
      completion?()
    })
  }
  
  private func dismissOverlayViewController(animated: Bool, completion: (() -> ())?) {
    overlayViewController?.dismiss(animated: animated) { [weak self] in
      self?.isOverlayViewExpanded = false
      completion?()
    }
  }
}

extension OverlayTabBarController: UIAdaptivePresentationControllerDelegate {
  public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    isOverlayViewExpanded = false
  }
}


