import Foundation

/// Asks the bundled yt-dlp for a playable stream and the chapter list of a YouTube video.
/// Results are cached per video, and repeated requests for the same video share one run.
final class StreamResolver {
    struct Stream {
        let id: String
        let url: String
        let title: String
        let chapters: [[String: Any]]
    }

    private let queue = DispatchQueue(label: "adfree.resolver", qos: .userInitiated)
    private var cache: [String: Stream] = [:]
    private var waiting: [String: [(Stream?, String?) -> Void]] = [:]

    /// The helper is signed on its own with the inherit entitlement (see build.sh).
    static var binary: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/yt-dlp/yt-dlp_macos")
    }

    func resolve(_ id: String, completion: @escaping (Stream?, String?) -> Void) {
        queue.async { [self] in
            if let hit = cache[id] { return DispatchQueue.main.async { completion(hit, nil) } }
            if waiting[id] != nil { waiting[id]?.append(completion); return }
            waiting[id] = [completion]
            let (stream, problem) = run(id)
            if let stream { cache[id] = stream }
            let callbacks = waiting.removeValue(forKey: id) ?? []
            DispatchQueue.main.async { callbacks.forEach { $0(stream, problem) } }
        }
    }

    private func run(_ id: String) -> (Stream?, String?) {
        guard FileManager.default.isExecutableFile(atPath: Self.binary.path) else {
            return (nil, "yt-dlp is not bundled. Run ./build.sh to download it.")
        }
        // Only the video id is passed, never the page URL, so nothing else reaches the command line.
        guard id.range(of: "^[A-Za-z0-9_-]{6,20}$", options: .regularExpression) != nil else {
            return (nil, "Unrecognised video id.")
        }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("adfree-ytdlp", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = Self.binary
        process.arguments = ["-J", "--no-playlist", "--no-warnings", "--cache-dir", tmp.path,
                             "https://www.youtube.com/watch?v=\(id)"]
        var env = ProcessInfo.processInfo.environment
        env["TMPDIR"] = tmp.path + "/"
        process.environment = env
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do { try process.run() } catch { return (nil, "Couldn't start yt-dlp: \(error.localizedDescription)") }
        // Give up after 90 seconds so a hung run can't block the queue forever.
        let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 90, execute: killer)
        // Read before waiting: the JSON is large enough to fill the pipe and stall the process.
        var errData = Data()
        let errRead = DispatchWorkItem { errData = err.fileHandleForReading.readDataToEndOfFile() }
        DispatchQueue.global().async(execute: errRead)
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        killer.cancel()
        errRead.wait()

        guard process.terminationStatus == 0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let tail = String(data: errData, encoding: .utf8)?
                .split(separator: "\n").last.map(String.init) ?? "exit \(process.terminationStatus)"
            return (nil, String(tail.prefix(200)))
        }
        return parse(id, json)
    }

    private func parse(_ id: String, _ json: [String: Any]) -> (Stream?, String?) {
        let formats = json["formats"] as? [[String: Any]] ?? []
        // Preferred: the HLS master playlist (video and audio, quality picked automatically by WebKit).
        var url = formats.compactMap { $0["manifest_url"] as? String }.first
        if url == nil {
            // Fallback: the tallest single file that already contains audio and video.
            url = formats
                .filter { ($0["vcodec"] as? String) != "none" && ($0["acodec"] as? String) != "none"
                    && ($0["protocol"] as? String) == "https" }
                .max { ($0["height"] as? Int ?? 0) < ($1["height"] as? Int ?? 0) }?["url"] as? String
        }
        guard let url else { return (nil, "No playable stream found.") }
        let chapters = (json["chapters"] as? [[String: Any]] ?? []).compactMap { c -> [String: Any]? in
            guard let start = c["start_time"] as? Double, let title = c["title"] as? String else { return nil }
            return ["t": start, "title": title]
        }
        return (Stream(id: id, url: url, title: json["title"] as? String ?? "", chapters: chapters), nil)
    }
}
