//
//  ReviewTableViewCell.swift
//  Sample
//
//  Created by Théophane Rupin on 5/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import API

@objc final class ReviewTableViewCellViewModel: NSObject {
    
    let content: String
    let author: String

    @objc(initWithReview:) init(_ review: Review) {
        content = review.properties.content
        author = review.properties.author
    }
}

@objc final class ReviewTableViewCell: UITableViewCell {
    
    private lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .black
        label.backgroundColor = .white
        return label
    }()
    
    private lazy var authorLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.textColor = .black
        label.backgroundColor = .white
        label.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        return label
    }()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = .clear

        contentView.addSubview(authorLabel)
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentLabel)
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            authorLabel.topAnchor.constraintEqualToSystemSpacingBelow(contentView.topAnchor, multiplier: 1),
            authorLabel.leadingAnchor.constraintEqualToSystemSpacingAfter(contentView.leadingAnchor, multiplier: 1),
            contentView.trailingAnchor.constraintEqualToSystemSpacingAfter(authorLabel.trailingAnchor, multiplier: 1),

            contentLabel.topAnchor.constraintEqualToSystemSpacingBelow(authorLabel.bottomAnchor, multiplier: 1),
            contentView.bottomAnchor.constraintEqualToSystemSpacingBelow(contentLabel.bottomAnchor, multiplier: 1),
            contentLabel.leadingAnchor.constraintEqualToSystemSpacingAfter(contentView.leadingAnchor, multiplier: 1),
            contentView.trailingAnchor.constraintEqualToSystemSpacingAfter(contentLabel.trailingAnchor, multiplier: 1)
        ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc(bindWithViewModel:) func bind(_ viewModel: ReviewTableViewCellViewModel) {
        contentLabel.text = viewModel.content
        authorLabel.text = "By \(viewModel.author)"
    }
}
