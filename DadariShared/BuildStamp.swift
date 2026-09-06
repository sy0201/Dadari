import Foundation

#if DEBUG
/// 지금 실행 중인 바이너리가 언제 빌드된 것인지 알려준다.
///
/// 잠금화면 위젯은 앱을 새로 설치해도 **이전 빌드의 익스텐션에 물린 채로 남는 일이 잦다.**
/// 그러면 코드를 고쳐도 동작이 바뀌지 않아 코드를 의심하게 되는데, 실제로는 옛 바이너리가
/// 돌고 있는 것이다. 1주차와 5~8주차에 각각 한 번씩 여기에 시간을 썼다.
///
/// 그래서 DEBUG 빌드에서는 위젯에 빌드 시각을 함께 표시하고 인텐트 로그에도 남긴다.
/// 위젯에 찍힌 시각이 방금 빌드한 시각과 다르면 코드를 보기 전에 위젯을 다시 추가하면 된다.
///
/// 번들 실행 파일의 수정 시각을 쓴다. 빌드할 때마다 새로 써지므로 빌드마다 값이 달라지고,
/// 앱과 위젯 익스텐션이 각자 자기 번들을 보기 때문에 둘을 따로 구분할 수 있다.
enum BuildStamp {
    static let short: String = {
        guard let url = Bundle.main.executableURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date else {
            return "?"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: modified)
    }()
}
#endif
