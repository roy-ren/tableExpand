//
//  ListExpandView.swift
//  TableExpand
//
//  Created by roy on 2020/3/30.
//  Copyright © 2020 royite. All rights reserved.
//

import UIKit
import SnapKit

public struct OKCoreWrapper<Base> {
    
    public let base: Base
    
    public init(_ base: Base) {
        self.base = base
    }
}

public protocol OKCoreCompatible {}

extension OKCoreCompatible {
    public var ok: OKCoreWrapper<Self> {
        return OKCoreWrapper<Self>(self)
    }
}

extension UIView: OKCoreCompatible {}

extension OKCoreWrapper where Base: UIView {
    public typealias ConstraintMakerClosure = (SnapKit.ConstraintMaker) -> Void
    public typealias ConfigClosure = (Base) -> Void
    
    @discardableResult
    public func added(to superView: UIView, layout layoutClosure: ConstraintMakerClosure? = nil, config configClosure: ConfigClosure? = nil) -> Base {
        added(to: superView)
        
        if let closure = layoutClosure {
            layout(closure)
        }
        
        if let closure = configClosure {
            config(closure)
        }
        
        return base
    }
    
    @discardableResult
    public func added(to superView: UIView) -> Base {
        superView.addSubview(base)
        return base
    }
    
    @discardableResult
    public func config(_ closure: (Base) -> Void) -> Base {
        closure(base)
        return base
    }
    
    @discardableResult
    public func layout(_ closure: (SnapKit.ConstraintMaker) -> Void) -> Base {
        base.snp.makeConstraints(closure)
        return base
    }
    
    @discardableResult
    public func updateLayout(_ closure: (SnapKit.ConstraintMaker) -> Void) -> Base {
        base.snp.updateConstraints(closure)
        return base
    }
    
    @discardableResult
    public func remakeLayout(_ closure: (SnapKit.ConstraintMaker) -> Void) -> Base {
        base.snp.remakeConstraints(closure)
        return base
    }
}


protocol MenuCostomerListSelectElement {
	var name: String { get }
}

extension Int: MenuCostomerListSelectElement {
	var name: String { "name" + String(self) }
}

let screenWidth = UIScreen.main.bounds.width

class MenuCostomerListSelectorView<Element: MenuCostomerListSelectElement>: UIView, UITableViewDataSource, UITableViewDelegate {
//	var selectElementIndex: Observable<Element> { selectElementSubject.asObservable() }
	
	typealias Element = String
	
	private let elements: [Element]
	private var selectedIndex: Int
//	private let selectElementSubject = PublishSubject<Element>()
	private let table = UITableView()
	private let rowHeight: CGFloat = 44
	private var state: State = .collapsed
	private let effectView = VisualEffectView()
	private let shadowView = UIView()
	private var hasConstructSubviews = false
	private let animator = UIViewPropertyAnimator(duration: 0.25, curve: .easeOut)
	private let popupOffset: CGFloat = (UIScreen.main.bounds.height) / 2.0

	private lazy var panRecognizer: UIPanGestureRecognizer = {
		let recognizer = UIPanGestureRecognizer()
		recognizer.addTarget(self, action: #selector(popupViewPanned(recognizer:)))
	 
		return recognizer
	 
	}()
	
	init(elements: [Element], selectedIndex: Int) {
		self.elements = elements
		self.selectedIndex = selectedIndex
		
		super.init(frame: .zero)
		clipsToBounds = true
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
//	deinit {
//		selectElementSubject.onCompleted()
//	}
	
	override func didMoveToWindow() {
		super.didMoveToWindow()
		
		guard !hasConstructSubviews else {
			return
		}
		constructSubview()
		hasConstructSubviews = true
	}

	private func constructSubview() {
		effectView.ok.added(to: self, layout: {
			$0.edges.equalToSuperview()
		}, config: {
			$0.blurRadius = 0
			$0.colorTint = .black
			$0.addGestureRecognizer(self.panRecognizer)
		})
		
		let tableHeight = CGFloat(self.elements.count) * self.rowHeight
		addSubview(shadowView)
		shadowView.ok.config {
			$0.backgroundColor = .white
			$0.layer.cornerRadius = 20
			$0.layer.shadowColor = UIColor.black.cgColor
			$0.layer.shadowOffset = .init(width: 0, height: 2)
			$0.layer.shadowRadius = 7
			$0.layer.shadowOpacity = 0.28
		}
		
		addSubview(table)
		table.frame = CGRect(x: 0, y: -tableHeight, width: screenWidth, height: tableHeight)
		table.ok.config {
			$0.rowHeight = self.rowHeight
			$0.dataSource = self
			$0.delegate = self
			$0.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
			$0.tableFooterView = .init()
			$0.isScrollEnabled = false
		}
		
		shadowView.frame = CGRect(x: 0, y: -30, width: screenWidth, height: 50)
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		elements.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
		
		cell.textLabel?.font = .systemFont(ofSize: 13)
		cell.textLabel?.text = elements[indexPath.row].name
		
		if indexPath.row ==  selectedIndex {
			cell.textLabel?.textColor = .blue
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		selectedIndex = indexPath.row
		tableView.reloadData()
		
//		selectElementSubject.onNext(self.elements[indexPath.row])
	}
	
	@objc func popupViewPanned(recognizer: UIPanGestureRecognizer) {
		switch recognizer.state {
		case .began:
			toggle()
			animator.pauseAnimation()
	 
		case .changed:
			let translation = recognizer.translation(in: effectView)
			var fraction = -translation.y / popupOffset
			if state == .expanded { fraction *= -1 }
			animator.fractionComplete = fraction
	 
		case .ended:
			animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
	 
		default:
			()
		}
	}
}

extension MenuCostomerListSelectorView {
	enum State {
		case collapsed
		case expanded
	}
	
	func show(on superView: UIView, layout: (SnapKit.ConstraintMaker) -> Void) {
		superView.addSubview(self)
		self.snp.makeConstraints(layout)
		expand()
	}
	
	func hide() {
		collapse()
	}
	
	func toggle() {
		switch state {
		case .expanded:
			collapse()
		case .collapsed:
			expand()
		}
	}
	
	private func expand() {
		animateTransition(to: .expanded)
	}
	
	private func collapse() {
		animateTransition(to: .collapsed) {
			self.removeFromSuperview()
		}
	}
	
	typealias VoidClosure = () -> Void
	private func animateTransition(
		to state: State,
		completion: VoidClosure? = nil
	) {
		let tableHeight = CGFloat(self.elements.count) * self.rowHeight
		animator.addAnimations {
			switch state {
			case .collapsed:
				self.effectView.blurRadius = 0
				self.table.frame.origin.y = -tableHeight
				self.shadowView.frame.origin.y = -50
				self.shadowView.layer.shadowOpacity = 0
			case .expanded:
				self.effectView.blurRadius = 5
				self.table.frame.origin.y = 0
				self.shadowView.frame.origin.y = tableHeight - 30
				self.shadowView.layer.shadowOpacity = 0.28
			}
		}
		
		animator.addCompletion { _ in
			self.state = state
			completion?()
		}
		
		animator.startAnimation()
	}
}
