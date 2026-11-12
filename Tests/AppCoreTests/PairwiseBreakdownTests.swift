import XCTest
import ScoringEngine
@testable import AppCore

final class PairwiseBreakdownTests: XCTestCase {
    let names = ["阿明", "阿強", "阿珍", "阿芬"]
    let hk = ScoreFormatting(region: .hongKong)

    /// Kenny's example: 香港炒 0 / 11 / 13 / 3 → penalties 0 / 33 / 52 / 3.
    func testKennysExample() throws {
        let round = try ScoringEngine.score(cardsLeft: [0, 11, 13, 3], rule: .hongKongDefault, mode: .pairwise)
        let b = RoundPresentation.pairwiseBreakdown(from: round)
        XCTAssertEqual(hk.pairwiseBreakdown(b[0], names: names), "贏阿珍 52 張、贏阿強 33 張、贏阿芬 3 張")
        XCTAssertEqual(hk.pairwiseBreakdown(b[1], names: names), "贏阿珍 19 張、輸阿明 33 張、輸阿芬 30 張")
        XCTAssertEqual(hk.pairwiseBreakdown(b[2], names: names), "輸阿明 52 張、輸阿芬 49 張、輸阿強 19 張")
        XCTAssertEqual(hk.pairwiseBreakdown(b[3], names: names), "贏阿珍 49 張、贏阿強 30 張、輸阿明 3 張")
        XCTAssertEqual(ScoreFormatting(region: .taiwan).pairwiseBreakdown(b[1], names: names),
                       "贏阿珍 19 張、輸阿明 33 張、輸阿芬 30 張")
    }

    func testBreakdownSumsToNetPoints() throws {
        let round = try ScoringEngine.score(cardsLeft: [4, 0, 12, 9], rule: .hongKongDefault, mode: .pairwise)
        for (i, items) in RoundPresentation.pairwiseBreakdown(from: round).enumerated() {
            let net = items.reduce(0) { sum, item in
                switch item.outcome {
                case .win: return sum + item.amount
                case .lose: return sum - item.amount
                case .tie: return sum
                }
            }
            XCTAssertEqual(net, round.scores[i].points, "player \(i)")
            XCTAssertEqual(items.count, 3)
        }
    }

    func testEqualPenaltiesShowTieLast() throws {
        let round = try ScoringEngine.score(cardsLeft: [0, 5, 5, 2], rule: .hongKongDefault, mode: .pairwise)
        let b = RoundPresentation.pairwiseBreakdown(from: round)
        XCTAssertEqual(hk.pairwiseBreakdown(b[1], names: names), "輸阿明 5 張、輸阿芬 3 張、和阿珍")
        XCTAssertEqual(hk.pairwiseBreakdown(b[0], names: names), "贏阿強 5 張、贏阿珍 5 張、贏阿芬 2 張")
    }
}
