// RUN: %target-run-simple-swift( -Xfrontend -disable-availability-checking -parse-as-library) | %FileCheck %s --dump-input=always

// REQUIRES: executable_test
// REQUIRES: concurrency

// rdar://76038845
// UNSUPPORTED: use_os_stdlib
// UNSUPPORTED: back_deployment_runtime

struct Boom: Error {}
struct IgnoredBoom: Error {}

@available(SwiftStdlib 5.5, *)
func one() async -> Int { 1 }

@available(SwiftStdlib 5.5, *)
func boom() async throws -> Int {
  throw Boom()
}

@available(SwiftStdlib 5.5, *)
func test_taskGroup_throws() async {
  let got: Int = try await withThrowingTaskGroup(of: Int.self) { group in
    group.spawn { try await boom()  }

    do {
      while let r = try await group.next() {
        print("next: \(r)")
      }
    } catch {
      print("error caught in group: \(error)")

      let gc = group.isCancelled
      print("group cancelled: \(gc)")

      group.spawn { () async -> Int in
        let c = Task.isCancelled
        print("task 3 (cancelled: \(c))")
        return 3
      }

      guard let third = try! await group.next() else {
        print("task group failed to get 3")
        return 0
      }

      print("task group returning normally: \(third)")
      return third
    }

    fatalError("Should have thrown and handled inside the catch block")
  }

  // CHECK: error caught in group: Boom()
  // CHECK: group cancelled: false
  // CHECK: task 3 (cancelled: false)
  // CHECK: task group returning normally: 3
  // CHECK: got: 3

  print("got: \(got)")
}


@available(SwiftStdlib 5.5, *)
@main struct Main {
  static func main() async {
    await test_taskGroup_throws()
  }
}
