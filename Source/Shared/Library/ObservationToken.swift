//
//  ObservationToken.swift
//  Cache
//
//  Created by Sam Spencer on 10/20/2022.
//  Copyright © 2022 nenos, llc. All rights reserved.
//

import Foundation

public final class ObservationToken {
    
    private let cancellationClosure: () -> Void
    
    init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }
    
    public func cancel() {
        cancellationClosure()
    }
    
}
