//
//  TweakCollectionViewController.swift
//  SwiftTweaks
//
//  Created by Bryan Clark on 11/10/15.
//  Copyright © 2015 Khan Academy. All rights reserved.
//

import UIKit

internal protocol TweakCollectionViewControllerDelegate {
	func tweakCollectionViewControllerDidPressDismissButton(_ tweakCollectionViewController: TweakCollectionViewController)
	func tweakCollectionViewController(_ tweakCollectionViewController: TweakCollectionViewController, didTapFloatingTweakGroupButtonForTweakGroup tweakGroup: TweakGroup)
}

/// Displays the contents of a TweakCollection in a table - each child TweakGroup gets a section, each Tweak<T> gets a cell.
internal final class TweakCollectionViewController: UIViewController {
	fileprivate let tweakCollection: TweakCollection
	fileprivate let tweakStore: TweakStore

	fileprivate let delegate: TweakCollectionViewControllerDelegate

	fileprivate let tableView: UITableView = {
		let tableView = UITableView(frame: CGRect.zero, style: .grouped)
		tableView.keyboardDismissMode = .onDrag
		return tableView
	}()

	init(tweakCollection: TweakCollection, tweakStore: TweakStore, delegate: TweakCollectionViewControllerDelegate) {
		self.tweakCollection = tweakCollection
		self.tweakStore = tweakStore
		self.delegate = delegate

		super.init(nibName: nil, bundle: nil)

		title = tweakCollection.title

		toolbarItems = [
			UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
			UIBarButtonItem(title: TweaksViewController.dismissButtonTitle, style: .done, target: self, action: #selector(self.dismissButtonTapped))
		]
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.frame = view.bounds
		tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		tableView.delegate = self
		tableView.dataSource = self
		tableView.register(TweakTableCell.self, forCellReuseIdentifier: TweakCollectionViewController.TweakTableViewCellIdentifer)
		tableView.register(TweakGroupSectionHeader.self, forHeaderFooterViewReuseIdentifier: TweakGroupSectionHeader.identifier)
		view.addSubview(tableView)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		// Reload data (in case colors were changed on a divedown)
		tableView.reloadData()
	}


	// MARK: Events

	@objc private func dismissButtonTapped() {
		delegate.tweakCollectionViewControllerDidPressDismissButton(self)
	}


	// MARK: Table Cells

	fileprivate static let TweakTableViewCellIdentifer = "TweakTableViewCellIdentifer"

}

extension TweakCollectionViewController: UITableViewDelegate {
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let tweak = tweakAtIndexPath(indexPath)
		switch tweak.tweakViewDataType {
		case .uiColor:
			let colorEditVC = TweakColorEditViewController(anyTweak: tweak, tweakStore: tweakStore, delegate: self)
			navigationController?.pushViewController(colorEditVC, animated: true)
		case .boolean, .integer, .cgFloat, .double:
			break
		}
	}
}

extension TweakCollectionViewController: UITableViewDataSource {
	func numberOfSections(in tableView: UITableView) -> Int {
		return tweakCollection.tweakGroups.count
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return tweakCollection.sortedTweakGroups[section].tweaks.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let tweak = tweakAtIndexPath(indexPath)

		let cell = tableView.dequeueReusableCell(withIdentifier: TweakCollectionViewController.TweakTableViewCellIdentifer, for: indexPath) as! TweakTableCell
		cell.textLabel?.text = tweak.tweakName
		cell.viewData = tweakStore.currentViewDataForTweak(tweak)
		cell.delegate = self
		return cell
	}

	private static let sectionFooterHeight: CGFloat = 27

    private func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
		return TweakCollectionViewController.sectionFooterHeight
	}

	private func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return TweakGroupSectionHeader.height
	}

	private func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: TweakGroupSectionHeader.identifier) as! TweakGroupSectionHeader
		headerView.tweakGroup = tweakCollection.sortedTweakGroups[section]
		headerView.delegate = self
		return headerView
	}

	fileprivate func tweakAtIndexPath(_ indexPath: IndexPath) -> AnyTweak {
		return tweakCollection.sortedTweakGroups[indexPath.section].sortedTweaks[indexPath.row]
	}
}

extension TweakCollectionViewController: TweakTableCellDelegate {
	func tweakCellDidChangeCurrentValue(_ tweakCell: TweakTableCell) {
		if
			let indexPath = tableView.indexPath(for: tweakCell),
			let viewData = tweakCell.viewData
		{
			let tweak = tweakAtIndexPath(indexPath)
			tweakStore.setValue(viewData, forTweak: tweak)
		}
	}
}

extension TweakCollectionViewController: TweakColorEditViewControllerDelegate {
	func tweakColorEditViewControllerDidPressDismissButton(_ tweakColorEditViewController: TweakColorEditViewController) {
		self.delegate.tweakCollectionViewControllerDidPressDismissButton(self)
	}
}

extension TweakCollectionViewController: TweakGroupSectionHeaderDelegate {
	fileprivate func tweakGroupSectionHeaderDidPressFloatingButton(_ sectionHeader: TweakGroupSectionHeader) {
		guard let tweakGroup = sectionHeader.tweakGroup else { return }

		delegate.tweakCollectionViewController(self, didTapFloatingTweakGroupButtonForTweakGroup: tweakGroup)
	}
}

private protocol TweakGroupSectionHeaderDelegate: class {
	func tweakGroupSectionHeaderDidPressFloatingButton(_ sectionHeader: TweakGroupSectionHeader)
}

/// Displays the name of a tweak group, and includes a (+) button to present the floating TweakGroup UI when tapped.
fileprivate final class TweakGroupSectionHeader: UITableViewHeaderFooterView {
	static let identifier = "TweakGroupSectionHeader"

	private let floatingButton: UIButton = {
		let button = UIButton(type: .custom)
		let buttonImage = UIImage(swiftTweaksImage: .floatingPlusButton).withRenderingMode(.alwaysTemplate)
		button.setImage(buttonImage.imageTintedWithColor(AppTheme.Colors.controlTinted), for: UIControlState())
		button.setImage(buttonImage.imageTintedWithColor(AppTheme.Colors.controlTintedPressed), for: .highlighted)
		return button
	}()

	private let titleLabel: UILabel = {
		let label = UILabel()
		label.textColor = AppTheme.Colors.sectionHeaderTitleColor
		label.font = AppTheme.Fonts.sectionHeaderTitleFont

		return label
	}()

	fileprivate weak var delegate: TweakGroupSectionHeaderDelegate?

	var tweakGroup: TweakGroup? {
		didSet {
			titleLabel.text = tweakGroup?.title
		}
	}

	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)

		floatingButton.addTarget(self, action: #selector(self.floatingButtonTapped), for: .touchUpInside)

		contentView.addSubview(floatingButton)
		contentView.addSubview(titleLabel)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	static let height: CGFloat = 38
	private static let horizontalMargin: CGFloat = 12
	private static let floatingButtonSize = CGSize(width: 46, height: TweakGroupSectionHeader.height)

	override fileprivate func layoutSubviews() {
		super.layoutSubviews()

		let floatingButtonFrame = CGRect(
			origin: CGPoint(
				x: self.contentView.bounds.maxX - TweakGroupSectionHeader.floatingButtonSize.width,
				y: 0
			),
			size: TweakGroupSectionHeader.floatingButtonSize
		)
		floatingButton.frame = floatingButtonFrame

		let titleLabelFrame = CGRect(
			origin: CGPoint(
				x: TweakGroupSectionHeader.horizontalMargin,
				y: 0
			),
			size: CGSize(
				width: self.contentView.bounds.width - floatingButtonFrame.width - TweakGroupSectionHeader.horizontalMargin,
				height: TweakGroupSectionHeader.height
			)
		)
		titleLabel.frame = titleLabelFrame
	}

	@objc private func floatingButtonTapped() {
		delegate!.tweakGroupSectionHeaderDidPressFloatingButton(self)
	}
}
