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
  public var overlayViewMaximumHeight: CGFloat? = nil
  private func presentsOverlayViewAsModal(viewHeight: CGFloat? = nil) -> Bool {
    let viewHeight = viewHeight ?? view.frame.size.height
    if let overlayViewMaximumHeight = overlayViewMaximumHeight,
      overlayViewMaximumHeight < viewHeight {
      return false
    } else {
      return !isHorizontalSizeClassRegular
    }
  }
  
  private var overlayViewExpandedConstraints = LayoutConstraintGroup()
  private var overlayViewCollapsedConstraints = LayoutConstraintGroup()
  public var isOverlayViewPresented: Bool {
    return overlayViewController != nil
  }
  private var isOverlayViewTemporaryRemoved = false
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
  public var flexibleTabBar: UITabBar!
  private var flexibleTabBarCollapsedConstraintGroup = LayoutConstraintGroup()
  private var flexibleTabBarExpandedConstraintGroup = LayoutConstraintGroup()
  public var flexibleTabBarWidthWhenHorizontalSizeClassRegular: CGFloat = 375 {
    didSet {
      guard isHorizontalSizeClassRegular else { return }
      guard flexibleTabBarWidthWhenHorizontalSizeClassRegular != oldValue else { return }
      updateFlexibleTabBarConstraints()
    }
  }
  
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
  
  override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    guard !isOverlayViewTemporaryRemoved else { return }
    temporaryRemoveOverlayViewController()
    setupButterflyHandle()
    setupGestureResponder()
    layoutOverlayView(viewHeight: size.height)
  }
  
  override open func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    super.willTransition(to: newCollection, with: coordinator)
    guard traitCollection.horizontalSizeClass != newCollection.horizontalSizeClass else { return }
    guard overlayViewController != nil else { return }
    temporaryRemoveOverlayViewController()
    setupButterflyHandle()
    setupGestureResponder()
  }
  
  override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass else { return }
    layoutOverlayView()
  }
  
  private func layoutOverlayView(viewHeight: CGFloat? = nil) {
    if let previewView = previewingViewController?.view {
      previewView.setNeedsLayout()
    }
    
    setupFlexibleTabBar()
    if let overlayViewController = overlayViewController, let previewViewController = previewingViewController {
      setOverlayViewController(overlayViewController, previewingViewController: previewViewController, isExpanded: isOverlayViewExpanded, animated: false, viewHeight: viewHeight)
      updateView(viewHeight: viewHeight)
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
    
    flexibleTabBar = UITabBar()
    flexibleTabBar.barStyle = tabBar.barStyle
    flexibleTabBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(flexibleTabBar)
    updateFlexibleTabBarConstraints()
    updateFlexibleTabBarItems()
    setupPreviewingTabBar()
  }
  
  private func updateFlexibleTabBarConstraints() {
    guard let flexibleTabBar = self.flexibleTabBar else { return }
    flexibleTabBarCollapsedConstraintGroup.isActive = false
    flexibleTabBarExpandedConstraintGroup.isActive = false
    flexibleTabBar.removeConstraints(flexibleTabBarCollapsedConstraintGroup.constraints)
    flexibleTabBar.removeConstraints(flexibleTabBarExpandedConstraintGroup.constraints)
    flexibleTabBarCollapsedConstraintGroup.removeAll()
    flexibleTabBarExpandedConstraintGroup.removeAll()
    
    let leadingConstraint = flexibleTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor)
    flexibleTabBarCollapsedConstraintGroup.append(leadingConstraint)
    flexibleTabBarExpandedConstraintGroup.append(leadingConstraint)
    
    if isHorizontalSizeClassRegular {
      let topConstraint = flexibleTabBar.topAnchor.constraint(equalTo: tabBar.topAnchor)
      flexibleTabBarCollapsedConstraintGroup.append(topConstraint)
      flexibleTabBarExpandedConstraintGroup.append(topConstraint)
      let bottomConstraint = flexibleTabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
      flexibleTabBarCollapsedConstraintGroup.append(bottomConstraint)
      flexibleTabBarExpandedConstraintGroup.append(bottomConstraint)

      let widthConstraint = flexibleTabBar.widthAnchor.constraint(equalTo: tabBar.widthAnchor, constant: -flexibleTabBarWidthWhenHorizontalSizeClassRegular)
      flexibleTabBarCollapsedConstraintGroup.append(widthConstraint)
      flexibleTabBarExpandedConstraintGroup.append(widthConstraint)
      drawTabBarBorder()
    } else {
      let collapsedTopConstraint = flexibleTabBar.topAnchor.constraint(equalTo: tabBar.topAnchor)
      flexibleTabBarCollapsedConstraintGroup.append(collapsedTopConstraint)
      
      let expandedTopConstraint = flexibleTabBar.topAnchor.constraint(equalTo: view.bottomAnchor)
      flexibleTabBarExpandedConstraintGroup.append(expandedTopConstraint)
      
      let heightConstraint = flexibleTabBar.heightAnchor.constraint(equalTo: tabBar.heightAnchor)
      flexibleTabBarCollapsedConstraintGroup.append(heightConstraint)
      flexibleTabBarExpandedConstraintGroup.append(heightConstraint)
      let widthConstraint = flexibleTabBar.widthAnchor.constraint(equalTo: tabBar.widthAnchor)
      flexibleTabBarCollapsedConstraintGroup.append(widthConstraint)
      flexibleTabBarExpandedConstraintGroup.append(widthConstraint)
    }
    
    flexibleTabBar.delegate = self
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
  
  open func setOverlayViewController(_ overlayViewController: UIViewController, previewingViewController: UIViewController, isExpanded: Bool, animated: Bool = true, viewHeight: CGFloat? = nil) {
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
    setupOverlayViewConstraints(viewHeight: viewHeight)
    
    previewingViewController.didMove(toParent: self)
    if presentsOverlayViewAsModal(viewHeight: viewHeight) {
      overlayViewController.view.layer.masksToBounds = false
      overlayViewController.view.layer.cornerRadius = 0
      if isExpanded {
        presentOverlayViewController(animated: animated, completion: nil)
      }
    } else {
      overlayViewController.view.layer.masksToBounds = true
      overlayViewController.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
      overlayViewController.view.layer.cornerRadius = 12
      overlayViewController.didMove(toParent: self)
    }
    
    setupGestureRecognizers(view: previewingViewController.view)
    setupGestureResponder()
    gestureResponder?.isUserInteractionEnabled = isOverlayViewExpanded
    
    view.bringSubviewToFront(flexibleTabBar)
    isOverlayViewTemporaryRemoved = false
  }
  
  private func setupOverlayViewConstraints(viewHeight: CGFloat? = nil) {
    guard let overlayViewController = overlayViewController else { return }
    guard let previewViewController = previewingViewController else { return }
    overlayViewExpandedConstraints.isActive = false
    overlayViewCollapsedConstraints.isActive = false
    overlayViewController.view.removeConstraints(overlayViewExpandedConstraints.constraints)
    overlayViewController.view.removeConstraints(overlayViewCollapsedConstraints.constraints)
    
    previewViewController.view.translatesAutoresizingMaskIntoConstraints = false
    previewViewController.view.leadingAnchor.constraint(equalTo: previewingTabBar.leadingAnchor).isActive = true
    previewViewController.view.trailingAnchor.constraint(equalTo: previewingTabBar.trailingAnchor).isActive = true
    previewViewController.view.topAnchor.constraint(equalTo: previewingTabBar.topAnchor).isActive = true
    previewViewController.view.bottomAnchor.constraint(equalTo: previewingTabBar.bottomAnchor).isActive = true
    
    guard !presentsOverlayViewAsModal(viewHeight: viewHeight) else { return }
    let viewHeight = viewHeight ?? view.frame.size.height
    overlayViewController.view.translatesAutoresizingMaskIntoConstraints = false
    
    overlayViewCollapsedConstraints.removeAll()
    let collapsedTopConstraint = overlayViewController.view.topAnchor.constraint(equalTo: previewingTabBar.topAnchor)
    overlayViewCollapsedConstraints.append(collapsedTopConstraint)
    if let overlayViewMaximumHeight = overlayViewMaximumHeight {
      let collapsedHeightConstraint = overlayViewController.view.heightAnchor.constraint(equalToConstant: min(overlayViewMaximumHeight, viewHeight))
      overlayViewCollapsedConstraints.append(collapsedHeightConstraint)
    } else {
      let collapsedHeightConstraint = overlayViewController.view.heightAnchor.constraint(equalToConstant: viewHeight)
      overlayViewCollapsedConstraints.append(collapsedHeightConstraint)
    }
    let collapsedLeadingConstraint = overlayViewController.view.leadingAnchor.constraint(equalTo: previewingTabBar.leadingAnchor)
    let collapsedTrailingConstraint = overlayViewController.view.trailingAnchor.constraint(equalTo: previewingTabBar.trailingAnchor)
    overlayViewCollapsedConstraints.append(collapsedLeadingConstraint)
    overlayViewCollapsedConstraints.append(collapsedTrailingConstraint)
    
    overlayViewExpandedConstraints.removeAll()
    if let overlayViewMaximumHeight = overlayViewMaximumHeight {
      let expandedHeightConstraint = overlayViewController.view.heightAnchor.constraint(equalToConstant: min(overlayViewMaximumHeight, viewHeight))
      overlayViewExpandedConstraints.append(expandedHeightConstraint)
    } else {
      let expandedHeightConstraint = overlayViewController.view.heightAnchor.constraint(equalToConstant: viewHeight)
      overlayViewExpandedConstraints.append(expandedHeightConstraint)
    }
    
    let expandedBottomConstraint = overlayViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    let expandedLeadingConstraint = overlayViewController.view.leadingAnchor.constraint(equalTo: previewingTabBar.leadingAnchor)
    let expandedTrailingConstraint = overlayViewController.view.trailingAnchor.constraint(equalTo: previewingTabBar.trailingAnchor)
    overlayViewExpandedConstraints.append(expandedBottomConstraint)
    overlayViewExpandedConstraints.append(expandedLeadingConstraint)
    overlayViewExpandedConstraints.append(expandedTrailingConstraint)
    
    if isOverlayViewExpanded {
      overlayViewExpandedConstraints.isActive = true
    } else {
      overlayViewCollapsedConstraints.isActive = true
    }
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
    isOverlayViewTemporaryRemoved = true
    if presentsOverlayViewAsModal() {
      overlayViewController?.dismiss(animated: false, completion: nil)
    } else {
      overlayViewController?.view.removeFromSuperview()
    }
  }
  
  open func removeOverlayViewController(animated: Bool, completion: (() -> ())? = nil) {
    guard isOverlayViewPresented else { return }
    if presentsOverlayViewAsModal() {
      if isOverlayViewExpanded {
        dismissOverlayViewController(animated: animated) { [weak self] in
          guard let self = self else { return }
          self.butterflyHandle?.removeFromSuperview()
          if !self.isHorizontalSizeClassRegular {
            self.previewingTabBar.isHidden = true
          }
          self.previewingViewController?.willMove(toParent: nil)
          self.previewingViewController?.view.removeFromSuperview()
          self.previewingViewController?.removeFromParent()
          self.previewingViewController = nil
          completion?()
        }
      } else {
        butterflyHandle?.removeFromSuperview()
        if !isHorizontalSizeClassRegular {
          previewingTabBar.isHidden = true
        }
        previewingViewController?.willMove(toParent: nil)
        previewingViewController?.view.removeFromSuperview()
        previewingViewController?.removeFromParent()
        previewingViewController = nil
        completion?()
      }
      overlayViewController = nil
    } else {
      let overlayViewController = self.overlayViewController
      transitionIfNeededTo(state: .collapsed, duration: animated ? transitionDuration : 0) { [weak self] in
        overlayViewController?.willMove(toParent: nil)
        overlayViewController?.view.removeFromSuperview()
        overlayViewController?.removeFromParent()
        self?.butterflyHandle?.removeFromSuperview()
        if self?.isHorizontalSizeClassRegular == false {
          self?.previewingTabBar.isHidden = true
        }
        self?.previewingViewController?.willMove(toParent: nil)
        self?.previewingViewController?.view.removeFromSuperview()
        self?.previewingViewController?.removeFromParent()
        self?.previewingViewController = nil
        completion?()
      }
      self.overlayViewController = nil
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
  
  private func updateView(viewHeight: CGFloat? = nil) {
    if isOverlayViewExpanded {
      butterflyHandle?.alpha = 1
      dimmedView.alpha = presentsOverlayViewAsModal(viewHeight: viewHeight) ? 0 : 1.0
    } else {
      previewingViewController?.view.alpha = 1
      if hidesButterflyHandleWhenCollapsed {
        butterflyHandle?.alpha = 0
      }
      dimmedView.alpha = 0
    }
  }
  
  open func transitionIfNeededTo(state: OverlayViewState, duration: TimeInterval, completion: (() -> ())? = nil) {
    guard let overlayViewController = overlayViewController else { return }
    animations = []
    if presentsOverlayViewAsModal() {
      switch state {
      case .collapsed:
        dismissOverlayViewController(animated: true, completion: completion)
      case .expanded:
        presentOverlayViewController(animated: true, completion: completion)
      }
    } else {
      let frameAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
        switch state {
        case .expanded:
          self.overlayViewCollapsedConstraints.isActive = false
          self.overlayViewExpandedConstraints.isActive = true
          overlayViewController.view.isHidden = false
          self.view.bringSubviewToFront(overlayViewController.view)
          self.butterflyHandle?.alpha = 1
          self.flexibleTabBarCollapsedConstraintGroup.isActive = false
          self.flexibleTabBarExpandedConstraintGroup.isActive = true
            
          self.view.layoutIfNeeded()
        case .collapsed:
          self.overlayViewExpandedConstraints.isActive = false
          self.overlayViewCollapsedConstraints.isActive = true
          if self.hidesButterflyHandleWhenCollapsed {
            self.butterflyHandle?.alpha = 0
          }
          self.flexibleTabBarExpandedConstraintGroup.isActive = false
          self.flexibleTabBarCollapsedConstraintGroup.isActive = true
          self.view.bringSubviewToFront(self.flexibleTabBar)
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
    if overlayViewController.presentingViewController != nil {
        overlayViewController.dismiss(animated: false) { [weak self] in
            self?.present(overlayViewController, animated: animated, completion: { [weak self] in
                 self?.isOverlayViewExpanded = true
                 completion?()
               })
        }
    } else {
        present(overlayViewController, animated: animated, completion: { [weak self] in
             self?.isOverlayViewExpanded = true
             completion?()
           })
    }
  }
  
  private func dismissOverlayViewController(animated: Bool, completion: (() -> ())?) {
    overlayViewController?.dismiss(animated: animated) { [weak self] in
      self?.isOverlayViewExpanded = false
      completion?()
    }
  }
}

extension OverlayTabBarController: UIAdaptivePresentationControllerDelegate {
  public func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
    flexibleTabBarExpandedConstraintGroup.isActive = false
    flexibleTabBarCollapsedConstraintGroup.isActive = true
    view.setNeedsLayout()
  }
  
  public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    isOverlayViewExpanded = false
  }
}


