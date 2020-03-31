//
//  ViewController.swift
//  TableExpand
//
//  Created by roy on 2020/3/24.
//  Copyright © 2020 royite. All rights reserved.
//

import UIKit

func nodeLog(pre: String, backspace: Int = 1, _ s: @autoclosure () -> Any) {
	print(pre + " -> " + String(describing: s()))
	(0..<backspace).forEach { _ in
		print("\n")
	}
}

class ViewModel: ExpandCollapseTableDataSource {
	typealias Element = Int
	
	let root: Node
	var expandNodes: [Node]
	/// 最后一次刷新操作的id
	var lastRefeshOperatorID: String?
	let operatorAccessQueue = DispatchQueue(label: "ViewModel.operatorAccessQueue")
	
	var updateChange: (Change) -> Void
	
	init(
		root: Node = .init(element: 0, state: .collapse),
		updateChange: @escaping (Change) -> Void
	) {
		self.root = root
		self.updateChange = updateChange
		self.expandNodes = root.expandNodes()
	}
	
	func refreshSubDataSource(forRowAt index: Int, ofNodeID id: String) {
		guard let element = element(forRowAt: index) else { return }
		
		constructSubElements(for: element) {
			self.update(elements: $0, ofSuperNodeID: id, forRowAt: index)
		}
	}
	
	func expandTableDidNodeChange(_ change: Change) {
		updateChange(change)
	}

	private func constructSubElements(for element: Element, handler: @escaping ([Element]) -> Void) {
		let count = Int.random(in: (2...3))
		let baseValue = element * 10
		var values = Set<Int>()
		
		while values.count < count {
			let value = Int.random(in: (1...9))
			values.insert(value + baseValue)
		}
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			handler(Array(values))
		}
	}
}

class ViewController: UIViewController {
	typealias Change = UpdateNodesChange
	var viewModel: ViewModel?
	let tableView = UITableView()
	private let newView = UIView()
	private var listView: MenuCostomerListSelectorView<Int>?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		addTableView()
		
		newView.ok.added(to: view, layout: {
			$0.leading.trailing.equalToSuperview()
			$0.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
			$0.height.equalTo(100)
		}, config: {
			$0.backgroundColor = .purple
		})
	}

	@IBAction func change(_ sender: Any) {
//		viewModel = .init() { [weak self] in
//			guard let self = self else { return }
//			self.updateTable(of: $0)
//		}
//
//		tableView.reloadData()
		
		if let view = listView {
			view.hide()
			listView = nil
			return
		}
		
		let listFilterView = MenuCostomerListSelectorView(
			elements: [0, 1, 2, 3, 4, 5, 6],
			selectedIndex: 2
		)
		
		listFilterView.show(on: view) {
			$0.leading.trailing.bottom.equalToSuperview()
			$0.top.equalTo(self.newView.snp.bottom)
		}
		
		listView = listFilterView
	}
	
	func updateTable(of change: Change) {
		
		print("updateTable is: \(change)\n\n")
		let deleteIndexPaths = change.deletionRows.map({ IndexPath(row: $0, section: 0) })
		let insertIndexPaths = change.insertionRows.map({ IndexPath(row: $0, section: 0) })
		let modifyIndexPaths = change.modificationRows.map({ IndexPath(row: $0, section: 0) })

//		tableView.isUserInteractionEnabled = false
		tableView.performBatchUpdates({
			self.tableView.deleteRows(at: deleteIndexPaths, with: .fade)
			self.tableView.insertRows(at: insertIndexPaths, with: .fade)
			self.tableView.reloadRows(at: modifyIndexPaths, with: .fade)
		}) { (_) in
//			self.tableView.isUserInteractionEnabled = true
		}
	}

	func addTableView() {
		view.addSubview(tableView)
		tableView.translatesAutoresizingMaskIntoConstraints = false
		
		NSLayoutConstraint.activate([
			tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
		])
		
		tableView.dataSource = self
		tableView.delegate = self
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
	}
}

extension ViewController: UITableViewDataSource {
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		
		let index = indexPath.row
		
		if let element = viewModel?.element(forRowAt: index) {
			var pre = "row: \(index)"
			
			if let level = viewModel?.levelOfElement(forRowAt: index) {
				pre += (0...level).reduce("", { result, _ in result + "——" })
			}
			
			cell.textLabel?.text = pre + "item: \(element)"
		} else {
			cell.textLabel?.text = "item: nil"
		}
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//		viewModel?.expandNodes.count ?? 0
		30
	}
}

extension ViewController: UITableViewDelegate {
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		
		viewModel?.selectCell(forRowAt: indexPath.row)
	}
}

//	func modify(row: Int) {
//		guard let node = node(forRowAt: index) else { return }
//
//		switch Int.random(in: 0...3) {
//		case 0:
//			let news = constructNewNodes(for: node, limit: 1)
//			print("modify row: \(row) append \(news[0].data)")
//			node.append(subNode: news[0])
//		case 1:
//			print("modify row: \(row) removeFrist")
//			node.removeFrist()
//		case 2:
//			print("modify row: switch")
//			if let last = node.removeLast() {
//				node.insert(subNode: last, at: 0)
//			}
//		default:
//			print("modify row: \(row) nothing")
//			break
//		}
//	}
