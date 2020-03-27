//
//  Node.swift
//  TableExpand
//
//  Created by roy on 2020/3/26.
//  Copyright © 2020 royite. All rights reserved.
//

import Foundation

protocol ExpandCollapseTableDataSource: class {
	associatedtype Element: Hashable
	typealias Node = ExpandCollapseNode<Element>
	
	var root: Node { get }
	
	var expandNodes: [Node] { get set }

	/// 最后一次刷新操作的id
	var lastRefeshOperatorID: String? { get set }
	var operatorAccessQueue: DispatchQueue { get }
	
	/// 刷新指定 row 的子节点数据
	/// - Parameters:
	///   - index: expandNodes 中的 index
	///   - id: 此次刷新node的 id， 会在刷新该node的subNodes数据的时候校验
	func refreshSubDataSource(forRowAt index: Int, ofNodeID id: String)
	
	/// 数据树发生改变后，通知 table 更新UI
	/// - Parameter change: 数据变化
	func expandTableDidNodeChange(_ change: Change)
}

extension ExpandCollapseTableDataSource {
	var refreshAfterExpandEnabled: Bool {
		return true
	}
	
	func element(forRowAt index: Int) -> Element? {
		node(forRowAt: index)?.data
	}
	
	func levelOfElement(forRowAt index: Int) -> Int? {
		node(forRowAt: index)?.level
	}
	
	func update(
		elements: [Element],
		ofSuperNodeID nodeID: String,
		forRowAt index: Int
	) {
		func startUdpate(for operatorID: String) {
			defer {
				finishedOperator(of: operatorID)
			}
			
			guard let node = node(forRowAt: index), node.id == nodeID else { return }

			nodeLog(pre: "=== === === update elements operator", backspace: 0, operatorID)
			nodeLog(pre: "update elements", backspace: 0, elements)
			nodeLog(pre: "update elements for index", index)
			
			let newNodes = elements.map { Node(element: $0) }
			
			notifyNodeExpandChange(node.update(subNodes: newNodes), forRowAt: index)
		}
		
		func applyAndUpdate(tryAgain: Bool = true) {
			applyOperatorID { id in
				DispatchQueue.global().async {
					guard let operatorID = id else {
						if tryAgain {
							nodeLog(pre: "!!!!!! update elements ", backspace: 0, "tryAgain")
							DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
								applyAndUpdate(tryAgain: false)
							}
						} else {
							nodeLog(pre: "!!!!!!!!!! update elements ", backspace: 0, "tryAgain faild")
						}
						
						return
					}
					
					nodeLog(pre: " >> update elements applyedOperatorID", backspace: 0, operatorID)
					startUdpate(for: operatorID)
				}
			}
		}
		
		applyAndUpdate()
	}
	
	func selectCell(forRowAt index: Int) {
		func opeator(for id: String) {
			defer {
				finishedOperator(of: id)
			}
			nodeLog(pre: "------ selectCell start operator", backspace: 0, id)
			
			guard let node = node(forRowAt: index) else { return }
			
			var change: Change
			// 关闭、隐藏 subNode
			switch node.state {
			case .collapse:
				change = open(node: node)
				nodeLog(pre: "selectCell start for index *** open *** ", index)
				// 每次展开数据后，去刷新获取最新数据
				notifyRefreshSubDataSoure(forRowAt: index)
			case .expand:
				nodeLog(pre: "selectCell start for index *** close *** ", index)
				change = close(node: node)
			}
			
			notifyNodeExpandChange(change, forRowAt: index)
		}
		
		applyOperatorID { id in
			guard let id = id else {
				nodeLog(pre: "!!!!! selectCell fail for index", index)
				return
			}
			
			nodeLog(pre: " >> selectCell applyedOperatorID", backspace: 0, id)
			DispatchQueue.global().async {
				opeator(for: id)
			}
		}
	}
}

extension ExpandCollapseTableDataSource {
	typealias Change = UpdateNodesChange
	
	private func applyOperatorID(result: @escaping (String?) -> Void) {
		DispatchQueue.global().async {
			self.operatorAccessQueue.sync {
				guard nil == self.lastRefeshOperatorID else {
					result(nil)
					return
				}
				
				let newOperatorID = UUID().uuidString
				self.lastRefeshOperatorID = newOperatorID
				result(newOperatorID)
			}
		}
	}
	
	private func finishedOperator(of id: String) {
		DispatchQueue.global().async {
			self.operatorAccessQueue.sync {
				guard id == self.lastRefeshOperatorID else {
					nodeLog(pre: "!!!!!!!!!!!!!!!!! finished Operator ffail", backspace: 3, id)
					return
				}
				
				if id == self.lastRefeshOperatorID {
					self.lastRefeshOperatorID = nil
					nodeLog(pre: "---------------------------------------- finished Operator success", backspace: 3, id)
				} else {
					self.lastRefeshOperatorID = nil
					nodeLog(pre: "!!! ---------------------------------------- finished Operator fail", backspace: 3, id)
				}
				
			}
		}
	}
	
	private func notifyRefreshSubDataSoure(forRowAt index: Int) {
		guard refreshAfterExpandEnabled, let id = node(forRowAt: index)?.id else { return }
		refreshSubDataSource(forRowAt: index, ofNodeID: id)
	}
	
	private func notifyNodeExpandChange(_ change: Change, forRowAt index: Int) {
		guard !change.isEmpty else { return }
		
		let convertChange = convertToTableChange(forChange: change, forRowAt: index)
		
		DispatchQueue.main.async {
			self.expandTableDidNodeChange(convertChange)
		}
	}
	
	private func refreshExpandNodes() {
		nodeLog(pre: "before read", expandNodes.map { $0.data })
		expandNodes = root.expandNodes()
		nodeLog(pre: "after read", expandNodes.map { $0.data })
	}
	
	private func valideIndex(_ row: Int) -> Bool {
		row >= 0 && row < expandNodes.count
	}
	
	private func node(forRowAt index: Int) -> Node? {
		guard valideIndex(index) else { return nil }
		return expandNodes[index]
	}
	
	private func open(node: Node) -> Change {
		node.updateState(.expand)
	}
	
	private func close(node: Node) -> Change {
		node.updateState(.collapse)
	}
	
	private func convertToTableChange(forChange change: Change, forRowAt row: Int) -> Change {
		nodeLog(pre: "convert para", change)
		guard let tappedNode = node(forRowAt: row), let newSubNodes = tappedNode.subNodes else {
			return .init()
		}
		
		var oldSubNodes = [Node]()
		var nextRow = row + 1
		while let node = node(forRowAt: nextRow) {
			if node.level == tappedNode.level {
				break
			}

			if node.level == tappedNode.level + 1 {
				oldSubNodes.append(node)
			}

			nextRow += 1
		}
		
		/// 将该 node 内部的 index 转换为当前 table 显示的数据对应的 index
		/// 在从 super node （index == row） 开始， 在当前 index 之前，会有 index 个 兄弟 node
		/// index 对应的 node 与点击的 row 直接是该 node 之前的所有兄弟 node 展示的 rows
		/// - Parameter index: 需要转化的 index, 发生改变的节点内部的index
		/// - Returns: 当前 table 显示的数据对应的 index
		func convert(changeIndexInnerSubNode index: Int, toTableIndexWithSubNodes nodes: [Node]) -> Int {
			nodes[0..<index].reduce(0, { $0 + $1.visableRowCount }) + row + 1
		}
		
		/*
		
		删除当前 node 的时候
		1、table 中有显示它的 subNode（即：visableRowCount > 1 或 true == node.isSubNodeVisable）
		则应该同时将该 node 的 subNodes 删除；
		2、否则，只删除当前的 node
		
		同理：Insert
		*/
		func convert(rows: [Int], subNodes: [Node]) -> [Int] {
			return rows.reduce([]) { (result, row) in
				// 待删除的 node 在 table 中实际对应的 index
				let index = convert(changeIndexInnerSubNode: row, toTableIndexWithSubNodes: subNodes)
				// 待删除的 node 在 table 中当前展示的node个数（包括自己）
				let visableRowCount = subNodes[row].visableRowCount
				
				if visableRowCount > 1 {
					return result + [Int](index..<(index + visableRowCount))
				} else {
					return result + [index]
				}
			}
		}
		
		let deletions = convert(rows: change.deletionRows, subNodes: oldSubNodes)
		let insertions = convert(rows: change.insertionRows, subNodes: newSubNodes)
		let modifications = convert(rows: change.modificationRows, subNodes: oldSubNodes)
		
		refreshExpandNodes()
		
		return .init(
			deletions: deletions,
			insertions: insertions,
			modifications: modifications
		)
	}
}
