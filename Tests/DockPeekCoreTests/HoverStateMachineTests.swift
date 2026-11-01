import Testing
import DockPeekCore

private func makeMachine() -> HoverStateMachine {
    HoverStateMachine(openDelay: 10, closeDelay: 20)
}

/// A machine that shows pid 1 at time 10.
private func shownMachine() -> HoverStateMachine {
    var machine = makeMachine()
    machine.iconHovered(pid: 1, now: 0)
    _ = machine.advance(to: 10)
    return machine
}

@Test func showsAfterOpenDelay() {
    var machine = makeMachine()
    machine.iconHovered(pid: 1, now: 0)
    #expect(machine.advance(to: 9) == [])
    #expect(machine.advance(to: 10) == [.show(pid: 1)])
    #expect(machine.shownPID == 1)
}

@Test func leavingBeforeDelayCancelsShow() {
    var machine = makeMachine()
    machine.iconHovered(pid: 1, now: 0)
    machine.iconLeft(now: 5)
    #expect(machine.nextDeadline == nil)
    #expect(machine.advance(to: 100) == [])
}

@Test func fastSweepShowsOnlyLastIcon() {
    var machine = makeMachine()
    machine.iconHovered(pid: 1, now: 0)
    machine.iconHovered(pid: 2, now: 3)
    machine.iconHovered(pid: 3, now: 6)
    #expect(machine.advance(to: 15) == [])
    #expect(machine.advance(to: 16) == [.show(pid: 3)])
}

@Test func repeatedHoverKeepsDeadline() {
    var machine = makeMachine()
    machine.iconHovered(pid: 1, now: 0)
    machine.iconHovered(pid: 1, now: 5)
    #expect(machine.nextDeadline == 10)
    #expect(machine.advance(to: 10) == [.show(pid: 1)])
}

@Test func closesAfterLeavingIcon() {
    var machine = shownMachine()
    machine.iconLeft(now: 12)
    #expect(machine.nextDeadline == 32)
    #expect(machine.advance(to: 31) == [])
    #expect(machine.advance(to: 32) == [.close])
    #expect(machine.shownPID == nil)
}

@Test func pointerInPanelKeepsItOpen() {
    var machine = shownMachine()
    machine.iconLeft(now: 12)
    machine.pointerEnteredPanel()
    #expect(machine.advance(to: 100) == [])
    machine.pointerExitedPanel(now: 100)
    #expect(machine.advance(to: 119) == [])
    #expect(machine.advance(to: 120) == [.close])
}

@Test func dockHidingWhilePointerInPanelKeepsItOpen() {
    var machine = shownMachine()
    machine.pointerEnteredPanel()
    machine.iconLeft(now: 15)
    #expect(machine.advance(to: 100) == [])
    machine.pointerExitedPanel(now: 100)
    #expect(machine.advance(to: 120) == [.close])
}

@Test func enteringPanelForgetsStaleIconSelection() {
    var machine = shownMachine()
    // The Dock did not report that the pointer left the icon.
    machine.pointerEnteredPanel()
    machine.pointerExitedPanel(now: 50)
    #expect(machine.advance(to: 70) == [.close])
}

@Test func switchingIconsReplacesContentWithoutClosing() {
    var machine = shownMachine()
    machine.iconHovered(pid: 2, now: 15)
    #expect(machine.advance(to: 24) == [])
    #expect(machine.advance(to: 25) == [.show(pid: 2)])
    #expect(machine.shownPID == 2)
}

@Test func dismissClosesAndClearsEverything() {
    var machine = shownMachine()
    machine.iconLeft(now: 12)
    #expect(machine.dismiss() == [.close])
    #expect(machine.nextDeadline == nil)
    #expect(machine.shownPID == nil)
    #expect(machine.dismiss() == [])
}

@Test func nextDeadlineFollowsState() {
    var machine = makeMachine()
    #expect(machine.nextDeadline == nil)
    machine.iconHovered(pid: 1, now: 0)
    #expect(machine.nextDeadline == 10)
    _ = machine.advance(to: 10)
    #expect(machine.nextDeadline == nil)
    machine.iconLeft(now: 12)
    #expect(machine.nextDeadline == 32)
}

// The app whose panel is about to open is the one to prefetch.
@Test func pendingShowNamesTheAppToPrefetch() {
    var machine = makeMachine()
    machine.iconHovered(pid: 1, now: 0)
    #expect(machine.pendingShowPID == 1)
    _ = machine.advance(to: 10)
    #expect(machine.pendingShowPID == nil)
}

@Test func noPendingShowForTheShownApp() {
    var machine = shownMachine()
    machine.iconHovered(pid: 1, now: 11)
    #expect(machine.pendingShowPID == nil)
}

@Test func leavingTheIconClearsThePendingShow() {
    var machine = makeMachine()
    machine.iconHovered(pid: 1, now: 0)
    machine.iconLeft(now: 5)
    #expect(machine.pendingShowPID == nil)
}
