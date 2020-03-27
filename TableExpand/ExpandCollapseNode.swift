//
//  ExpandCollapseNode.swift
//  xim
//
//  Created by roy on 2020/3/24.
//  Copyright © 2020 xiaoman. All rights reserved.
//

import Foundation

struct UpdateNodesChange {
	let deletionRows: [Int]
	let insertionRows: [Int]
	let modificationRows: [Int]
	
	init(deletions: [Int] = [], insertions: [Int] = [], modifications: [Int] = []) {
		self.deletionRows = deletions
		self.insertionRows = insertions
		self.modificationRows = modifications
	}
	
	static let empty = UpdateNodesChange()
	
	var isEmpty: Bool {
		deletionRows.isEmpty && insertionRows.isEmpty && modificationRows.isEmpty
	}
}

// swiftlint:disable all
class ExpandCollapseNode<Element: Hashable> {
	typealias Change = UpdateNodesChange
	
	var data: Element { node.data }
	var subNodeCount: Int { node.subNodeCount }
	var subNodes: [ExpandCollapseNode]? { node.subNodes }
	
	var visableRowCount: Int {
		guard .expand == state else {
			return 1
		}

		if let nodes = subNodes {
			return nodes.reduce(1) {
				$0 + $1.visableRowCount
			}
		}

		return 1
	}
	
	weak var superNode: ExpandCollapseNode? {
		didSet {
			var newLevel = 0
			var node = superNode
			while let aSuper = node {
				newLevel += 1
				node = aSuper.superNode
			}
			
			level = newLevel
		}
	}
	
	private(set) var level: Int = 0 {
		didSet {
			guard oldValue != level else { return }
			subNodes?.forEach({ $0.superNode = self })
		}
	}
	
	private(set) var id: String
	private(set) var state: State
	private(set) var node: Node<Element>

	init(
		element: Element,
		subNodes: [ExpandCollapseNode]? = nil,
		state: State = .collapse
	) {
		self.state = state
		self.id = UUID().uuidString
		if let sub = subNodes {
			self.node = .branch(data: element, subNodes: sub)
			sub.forEach({ $0.superNode = self })
		} else {
			self.node = .leaf(data: element)
		}
	}
	
	func updateState(_ newState: State) -> Change {
		defer { state = newState }
		
		guard subNodeCount > 0 else { return .empty }
		
		switch newState {
		case .expand:
			return .init(insertions: [Int](0..<subNodeCount))
		case .collapse:
			return .init(deletions: [Int](0..<subNodeCount))
		}
	}
	
	/// 更新子节点
	/// - Parameter newNodes: 新的子节点
	/// - Returns: 跟新节点后引起的 expand list 的变化
	func update(subNodes newNodes: [ExpandCollapseNode]) -> Change {
		var updateNodes = newNodes
		
		defer {
			node.update(subNodes: updateNodes)
			updateNodes.forEach { $0.superNode = self }
		}
		
		// 如果该节点是闭合的，则不会引起expand list的变化
		guard .expand == state else {
			return .init()
		}
		
		guard let originNodes = subNodes else {
			return .init(insertions: [Int](0..<newNodes.count))
		}
					
		guard newNodes.count > 0 else {
			return .init(deletions: [Int](0..<originNodes.count))
		}
		
		let originSet = Set(originNodes.map({ $0.data }))
		let newSet = Set(newNodes.map({ $0.data }))
		
		let modifyItems = originSet.intersection(newSet)
		let deleteItems = originSet.subtracting(newSet)
		let insertItems = newSet.subtracting(originSet)
		
		var modifitionRows = [Int]()
		var deletionRows = [Int]()
		var insertionRows = [Int]()
		var modifitionRowsAtNew = [Int]()
		
		originNodes.enumerated().forEach {
			if deleteItems.contains($0.element.data) {
				deletionRows.append($0.offset)
			} else if modifyItems.contains($0.element.data) {
				modifitionRows.append($0.offset)
			}
		}
		
		newNodes.enumerated().forEach {
			if insertItems.contains($0.element.data) {
				insertionRows.append($0.offset)
			} else if modifyItems.contains($0.element.data) {
				modifitionRowsAtNew.append($0.offset)
			}
		}
		
		modifitionRows.forEach {
			let originNode = originNodes[$0]
			
			var index = 0
			while index < modifitionRowsAtNew.count {
				let newNodeIndex = modifitionRowsAtNew[index]
				let newNode = newNodes[newNodeIndex]
				
				if originNode.data == newNode.data {
					let node = ExpandCollapseNode(element: newNode.data, subNodes: originNode.subNodes, state: originNode.state)
					updateNodes.replaceSubrange((newNodeIndex...newNodeIndex), with: [node])
					modifitionRowsAtNew.remove(at: index)
					return
				}
				
				index += 1
			}
		}
		
		return .init(
			deletions: deletionRows,
			insertions: insertionRows,
			modifications: modifitionRows
		)
	}
	
	func totalNodes() -> [ExpandCollapseNode] {
		nodeList(isOnlyExpand: false)
	}
	
	func expandNodes() -> [ExpandCollapseNode] {
		nodeList(isOnlyExpand: true)
	}
	
	private func nodeList(isOnlyExpand: Bool) -> [ExpandCollapseNode] {
		if isOnlyExpand, .collapse == state {
			return [self]
		}
		
		// node: 节点, childCount: 节点的子节点个数, childReadIndex: 已阅读的子节点的index
		typealias StackItem = (node: ExpandCollapseNode, childCount: Int, childReadIndex: Int)
		var stack = [StackItem]()
		var list = [ExpandCollapseNode]()
		var node: ExpandCollapseNode? = self

		while node != nil || !stack.isEmpty {
			while let aNode = node {
				if isOnlyExpand, .collapse == aNode.state {
					list.append(aNode)
					node = nil
					continue
				}
				
				stack.append(StackItem(node: aNode, childCount: aNode.subNodeCount, childReadIndex: 0))
				list.append(aNode)
				node = aNode[0]
			}
			
			if !stack.isEmpty {
				let item = stack.removeLast()
				
				// 0 == item.childCount: 无子树
				// item.childCount == item.childReadIndex + 1 : 所有子树已阅读
				if item.childCount > 0, let child = item.node[item.childReadIndex + 1] {
					let newItem = StackItem(
						node: item.node,
						childCount: item.childCount,
						childReadIndex: item.childReadIndex + 1
					)
					stack.append(newItem)
					
					node = child
				}
			}
		}
		
		return list
	}
	
	/// 插入
	/// return：插入是否成功
	@discardableResult
	func insert(subNode: ExpandCollapseNode, at index: Int) -> Change {
		let result = node.insert(node: subNode, at: index)
		
		guard result else { return .empty }
		
		subNode.superNode = self
		return .init(insertions: [index])
	}
	
	func append(subNode: ExpandCollapseNode) -> Change {
		node.append(node: subNode)
		subNode.superNode = self
		
		return .init(insertions: [node.subNodeCount - 1])
	}

	/// 删除
	@discardableResult
	private func remove(at index: Int) -> (ExpandCollapseNode, Change)? {
		guard let removedNode = node.remove(at: index) else {
			return nil
		}
		
		removedNode.superNode = nil
		return (removedNode, .init(deletions: [index]))
	}
	
	@discardableResult
	func removeFrist() -> (ExpandCollapseNode, Change)? {
		remove(at: 0)
	}
	
	@discardableResult
	func removeLast() -> (ExpandCollapseNode, Change)? {
		remove(at: subNodeCount - 1)
	}
	
	func removeAll() -> Change {
		let count = subNodeCount
		guard let nodes = node.removeAll() else { return .empty }
		
		nodes.forEach({ $0.superNode = nil })
		return .init(deletions: [Int](0..<count))
	}
	
	subscript(index: Int) -> ExpandCollapseNode<Element>? {
		get {
			guard let nodes = subNodes, nodes.count > index else { return nil }
			return nodes[index]
		}
		set {
			if let newNode = newValue {
				node.insert(node: newNode, at: index)
			} else {
				node.remove(at: index)
			}
		}
	}
}

extension ExpandCollapseNode {
	enum State {
		/// 展开状态
		case expand
		/// 闭合状态
		case collapse
	}
	
	enum Node<Element: Hashable> {
		case branch(data: Element, subNodes: [ExpandCollapseNode])
		case leaf(data: Element)
		
		var data: Element {
			switch self {
			case .leaf(let data):
				return data
			case .branch(let data, _):
				return data
			}
		}
		
		var subNodes: [ExpandCollapseNode]? {
			switch self {
			case .leaf:
				return nil
			case .branch(_, let nodes):
				return nodes
			}
		}
		
		var subNodeCount: Int {
			switch self {
			case .leaf:
				return 0
			case .branch(_, let subNodes):
				return subNodes.count
			}
		}
		
		private func validate(index: Int, forInsert: Bool = false) -> Bool {
			index >= 0 && index <= (forInsert ? subNodeCount : subNodeCount - 1)
		}
		
		mutating func append(node: ExpandCollapseNode) {
			self = .branch(data: data, subNodes: (subNodes ?? []) + [node])
		}
		
		@discardableResult
		mutating func insert(node: ExpandCollapseNode, at index: Int) -> Bool {
			guard validate(index: index, forInsert: true) else { return false }
			
			var nodes = subNodes ?? []
			nodes.insert(node, at: index)
			self = .branch(data: data, subNodes: nodes)
			return true
		}
		
		mutating func update(subNodes newNodes: [ExpandCollapseNode]) {
			self = .branch(data: data, subNodes: newNodes)
		}
		
		@discardableResult
		mutating func remove(at index: Int) -> ExpandCollapseNode? {
			guard validate(index: index) else { return nil }
			
			var nodes = subNodes ?? []
			let removed = nodes.remove(at: index)
			if nodes.isEmpty {
				self = .leaf(data: data)
			} else {
				self = .branch(data: data, subNodes: nodes)
			}
			
			return removed
		}
		
		mutating func removeAll() -> [ExpandCollapseNode]? {
			let removedNodes = subNodes
			self = .leaf(data: data)
			return removedNodes
		}
	}
}


