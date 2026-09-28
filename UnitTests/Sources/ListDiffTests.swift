//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import Testing

struct ListDiffTests {
    @Test
    func appendAndPushes() {
        var array = [2]
        array.apply(.append([3, 4]))
        array.apply(.pushFront(1))
        array.apply(.pushBack(5))
        #expect(array == [1, 2, 3, 4, 5])
    }

    @Test
    func popsInsertSetRemove() {
        var array = [1, 2, 3, 4]
        array.apply(.popFront)
        array.apply(.popBack)
        array.apply(.insert(index: 1, value: 9))
        array.apply(.set(index: 0, value: 7))
        array.apply(.remove(index: 2))
        #expect(array == [7, 9])
    }

    @Test
    func truncateClearReset() {
        var array = [1, 2, 3]
        array.apply(.truncate(length: 1))
        #expect(array == [1])
        array.apply(.clear)
        #expect(array.isEmpty)
        array.apply(.reset([5, 6]))
        #expect(array == [5, 6])
    }

    @Test
    func outOfRangeDiffsAreIgnoredNotCrashing() {
        var array = [1]
        array.apply(.remove(index: 5))
        array.apply(.set(index: 3, value: 2))
        array.apply(.insert(index: 9, value: 2))
        array.apply(.truncate(length: 10))
        #expect(array == [1, 2])
    }

    @Test
    func popOnEmptyIsIgnored() {
        var array: [Int] = []
        array.apply(.popFront)
        array.apply(.popBack)
        #expect(array.isEmpty)
    }
}
