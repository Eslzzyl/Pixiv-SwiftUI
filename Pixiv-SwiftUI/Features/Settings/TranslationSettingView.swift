import SwiftUI
import TranslationKit

extension View {
    @ViewBuilder
    func autocapitalizationDisabled() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func urlKeyboardType() -> some View {
        #if os(iOS)
        self.keyboardType(.URL)
        #else
        self
        #endif
    }
}

struct TranslationSettingView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(ThemeManager.self) var themeManager

    @State private var primaryServiceId: String = ""
    @State private var targetLanguage: String = ""
    @State private var tapToTranslate: Bool = false
    @State private var openAIApiKey: String = ""
    @State private var openAIBaseURL: String = ""
    @State private var openAIModel: String = ""
    @State private var openAITemperature: Double = 0.3
    @State private var baiduAppid: String = ""
    @State private var baiduKey: String = ""
    @State private var googleApiKey: String = ""
    @State private var tencentSecretId: String = ""
    @State private var tencentSecretKey: String = ""
    @State private var tencentRegion: String = ""
    @State private var tencentProjectId: String = ""
    @State private var tagTranslationDisplayMode: Int = 2

    @State private var isTestingOpenAI: Bool = false
    @State private var isTestingBaidu: Bool = false
    @State private var isTestingGoogle: Bool = false
    @State private var isTestingGoogleAPI: Bool = false
    @State private var isTestingBing: Bool = false
    @State private var isTestingTencent: Bool = false
    @State private var isClearingCache: Bool = false
    @State private var cacheSize: String = "计算中..."
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    @State private var showClearCacheConfirmation: Bool = false

    var body: some View {
        Form {
            tapToTranslateSection
            servicePrioritySection
            languageSection
            tagTranslationDisplayModeSection
            serviceConfigSection
            cacheSection
        }
        .formStyle(.grouped)
        .onAppear {
            loadSettings()
            loadCacheSize()
        }
        .onDisappear {
            saveSettings()
        }
        .alert(String(localized: "确认清除"), isPresented: $showClearCacheConfirmation) {
            Button(String(localized: "取消"), role: .cancel) { }
            Button(String(localized: "清除"), role: .destructive) {
                clearCache()
            }
        } message: {
            Text(String(localized: "确定要清除所有小说翻译缓存吗？此操作不可撤销。"))
        }
        .toast(isPresented: $showToast, message: toastMessage)
    }

    private var tapToTranslateSection: some View {
        Section {
            LabeledContent(String(localized: "轻触翻译")) {
                Toggle("", isOn: $tapToTranslate)
                    #if os(macOS)
                    .toggleStyle(.switch)
                    #endif
            }
        } header: {
            Text(String(localized: "交互方式"))
        } footer: {
            Text(String(localized: "开启后点击文本可直接翻译，再次点击可收起翻译。"))
        }
    }

    private var servicePrioritySection: some View {
        Section {
            LabeledContent(String(localized: "当前服务")) {
                Picker("", selection: $primaryServiceId) {
                    ForEach(userSettingStore.availableTranslateServices, id: \.id) { service in
                        Text(service.name).tag(service.id)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text(String(localized: "服务设置"))
        } footer: {
            Text(String(localized: "选择用于翻译文本的服务。"))
        }
    }

    private var languageSection: some View {
        Section {
            LabeledContent(String(localized: "目标语言")) {
                Picker("", selection: $targetLanguage) {
                    ForEach(userSettingStore.availableLanguages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text(String(localized: "翻译语言"))
        } footer: {
            Text(String(localized: "翻译时默认将内容翻译为目标语言。"))
        }
    }

    private var tagTranslationDisplayModeSection: some View {
        Section {
            LabeledContent(String(localized: "标签翻译显示")) {
                Picker("", selection: $tagTranslationDisplayMode) {
                    Text(String(localized: "不显示译文")).tag(0)
                    Text(String(localized: "仅显示官方译文")).tag(1)
                    Text(String(localized: "使用本地的优化译文")).tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text(String(localized: "标签翻译"))
        } footer: {
            Text(String(localized: "选择标签翻译的显示方式。"))
        }
    }

    @ViewBuilder
    private var serviceConfigSection: some View {
        if primaryServiceId == "openai" {
            openAIServiceConfig
        }
        if primaryServiceId == "baidu" {
            baiduServiceConfig
        }
        if primaryServiceId == "google" {
            googleServiceConfig
        }
        if primaryServiceId == "googleapi" {
            googleApiServiceConfig
        }
        if primaryServiceId == "bing" {
            bingServiceConfig
        }
        if primaryServiceId == "tencent" {
            tencentServiceConfig
        }
    }

    private var openAIServiceConfig: some View {
        Section {
            SecureField(String(localized: "API Key"), text: $openAIApiKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()

            TextField(String(localized: "Base URL"), text: $openAIBaseURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()
                .urlKeyboardType()

            TextField(String(localized: "模型"), text: $openAIModel)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()

            VStack(alignment: .leading, spacing: 8) {
                Text("温度: \(openAITemperature, specifier: "%.1f")")
                Slider(value: $openAITemperature, in: 0...2, step: 0.1)
            }

            #if os(macOS)
            LabeledContent(String(localized: "测试服务")) {
                Button {
                    testOpenAIService()
                } label: {
                    HStack {
                        if isTestingOpenAI {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                        } else {
                            Text(String(localized: "测试"))
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTestingOpenAI || openAIApiKey.isEmpty)
            }
            #else
            Button {
                testOpenAIService()
            } label: {
                ZStack {
                    if isTestingOpenAI {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "测试服务"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: themeManager.currentColor))
            .disabled(isTestingOpenAI || openAIApiKey.isEmpty)
            #endif
        } header: {
            Text(String(localized: "OpenAI 配置"))
        } footer: {
            Text(String(localized: "配置 OpenAI 或兼容的 LLM 服务。API Key 为必填项，不配置将无法使用此服务。"))
        }
    }

    private var baiduServiceConfig: some View {
        Section {
            TextField(String(localized: "AppID"), text: $baiduAppid)
                .textContentType(.none)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()

            SecureField(String(localized: "API Key"), text: $baiduKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()

            #if os(macOS)
            LabeledContent(String(localized: "测试服务")) {
                Button {
                    testBaiduService()
                } label: {
                    HStack {
                        if isTestingBaidu {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                        } else {
                            Text(String(localized: "测试"))
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTestingBaidu || baiduAppid.isEmpty || baiduKey.isEmpty)
            }
            #else
            Button {
                testBaiduService()
            } label: {
                ZStack {
                    if isTestingBaidu {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Text(String(localized: "测试服务"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(GlassButtonStyle(color: themeManager.currentColor))
            .disabled(isTestingBaidu || baiduAppid.isEmpty || baiduKey.isEmpty)
            #endif
        } header: {
            Text(String(localized: "百度翻译配置"))
        } footer: {
            Text(String(localized: "请在百度翻译开放平台申请 AppID 和 API Key。"))
        }
    }

    private var googleServiceConfig: some View {
        Section {
            Text(String(localized: "Google 网页翻译无需配置，可直接使用。"))
                .foregroundColor(.secondary)

            #if os(macOS)
            LabeledContent(String(localized: "测试服务")) {
                Button {
                    testGoogleService()
                } label: {
                    HStack {
                        if isTestingGoogle {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                        } else {
                            Text(String(localized: "测试"))
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTestingGoogle)
            }
            #else
            Button {
                testGoogleService()
            } label: {
                ZStack {
                    if isTestingGoogle {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "测试服务"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: themeManager.currentColor))
            .disabled(isTestingGoogle)
            #endif
        } header: {
            Text(String(localized: "Google 网页翻译配置"))
        } footer: {
            Text(String(localized: "Google 网页翻译是免费的翻译服务，无需 API 密钥即可使用。"))
        }
    }

    private var googleApiServiceConfig: some View {
        Section {
            SecureField(String(localized: "API Key"), text: $googleApiKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()

            #if os(macOS)
            LabeledContent(String(localized: "测试服务")) {
                Button {
                    testGoogleAPIService()
                } label: {
                    HStack {
                        if isTestingGoogleAPI {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                        } else {
                            Text(String(localized: "测试"))
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTestingGoogleAPI || googleApiKey.isEmpty)
            }
            #else
            Button {
                testGoogleAPIService()
            } label: {
                ZStack {
                    if isTestingGoogleAPI {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "测试服务"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: themeManager.currentColor))
            .disabled(isTestingGoogleAPI || googleApiKey.isEmpty)
            #endif
        } header: {
            Text(String(localized: "Google Translate API 配置"))
        } footer: {
            Text(String(localized: "Google Translate API 需要 API Key，请在 Google Cloud Platform 申请。"))
        }
    }

    private var bingServiceConfig: some View {
        Section {
            Text(String(localized: "Bing 翻译无需配置，可直接使用。"))
                .foregroundColor(.secondary)

            #if os(macOS)
            LabeledContent(String(localized: "测试服务")) {
                Button {
                    testBingService()
                } label: {
                    HStack {
                        if isTestingBing {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                        } else {
                            Text(String(localized: "测试"))
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTestingBing)
            }
            #else
            Button {
                testBingService()
            } label: {
                ZStack {
                    if isTestingBing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "测试服务"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: themeManager.currentColor))
            .disabled(isTestingBing)
            #endif
        } header: {
            Text(String(localized: "Bing 翻译配置"))
        } footer: {
            Text(String(localized: "Bing 翻译是微软提供的免费翻译服务，无需 API 密钥即可使用。"))
        }
    }

    private var tencentServiceConfig: some View {
        Section {
            TextField(String(localized: "Secret ID"), text: $tencentSecretId)
                .textContentType(.none)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()

            SecureField(String(localized: "Secret Key"), text: $tencentSecretKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()

            TextField(String(localized: "区域"), text: $tencentRegion)
                .textContentType(.none)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()

            TextField(String(localized: "项目 ID"), text: $tencentProjectId)
                .textContentType(.none)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()

            #if os(macOS)
            LabeledContent(String(localized: "测试服务")) {
                Button {
                    testTencentService()
                } label: {
                    HStack {
                        if isTestingTencent {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                        } else {
                            Text(String(localized: "测试"))
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTestingTencent || tencentSecretId.isEmpty || tencentSecretKey.isEmpty)
            }
            #else
            Button {
                testTencentService()
            } label: {
                ZStack {
                    if isTestingTencent {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "测试服务"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: themeManager.currentColor))
            .disabled(isTestingTencent || tencentSecretId.isEmpty || tencentSecretKey.isEmpty)
            #endif
        } header: {
            Text(String(localized: "腾讯翻译配置"))
        } footer: {
            Text(String(localized: "请在腾讯云控制台申请 Secret ID 和 Secret Key。"))
        }
    }

    private var cacheSection: some View {
        Section {
            HStack {
                Text(String(localized: "缓存大小"))
                Spacer()
                Text(cacheSize)
                    .foregroundColor(.secondary)
            }

            #if os(macOS)
            LabeledContent(String(localized: "清除缓存")) {
                Button(role: .destructive) {
                    showClearCacheConfirmation = true
                } label: {
                    HStack {
                        if isClearingCache {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                        } else {
                            Text(String(localized: "清除"))
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isClearingCache)
            }
            #else
            Button(role: .destructive) {
                showClearCacheConfirmation = true
            } label: {
                ZStack {
                    if isClearingCache {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Text(String(localized: "清除所有小说翻译缓存"))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .disabled(isClearingCache)
            #endif
        } header: {
            Text(String(localized: "缓存管理"))
        } footer: {
            Text(String(localized: "清除后已翻译的内容需要重新翻译。内存缓存上限 100 条，磁盘缓存保留 30 天内的翻译结果。"))
        }
    }

    private func loadSettings() {
        primaryServiceId = userSettingStore.userSetting.translatePrimaryServiceId
        targetLanguage = userSettingStore.userSetting.translateTargetLanguage
        tapToTranslate = userSettingStore.userSetting.translateTapToTranslate
        tagTranslationDisplayMode = userSettingStore.userSetting.tagTranslationDisplayMode
        openAIApiKey = userSettingStore.userSetting.translateOpenAIApiKey
        openAIBaseURL = userSettingStore.userSetting.translateOpenAIBaseURL
        openAIModel = userSettingStore.userSetting.translateOpenAIModel
        openAITemperature = userSettingStore.userSetting.translateOpenAITemperature
        baiduAppid = userSettingStore.userSetting.translateBaiduAppid
        baiduKey = userSettingStore.userSetting.translateBaiduKey
        googleApiKey = userSettingStore.userSetting.translateGoogleApiKey
        tencentSecretId = userSettingStore.userSetting.translateTencentSecretId
        tencentSecretKey = userSettingStore.userSetting.translateTencentSecretKey
        tencentRegion = userSettingStore.userSetting.translateTencentRegion
        tencentProjectId = userSettingStore.userSetting.translateTencentProjectId
    }

    private func loadCacheSize() {
        Task {
            let size = await NovelTranslationCacheStore.shared.getCacheSize()
            await MainActor.run {
                cacheSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        }
    }

    private func clearCache() {
        guard !isClearingCache else { return }
        isClearingCache = true

        Task {
            await NovelTranslationCacheStore.shared.clearCache()
            await MainActor.run {
                isClearingCache = false
                cacheSize = "0 B"
                toastMessage = "缓存已清除"
                showToast = true
            }
        }
    }

    private func saveSettings() {
        try? userSettingStore.setTranslatePrimaryServiceId(primaryServiceId)
        try? userSettingStore.setTranslateTargetLanguage(targetLanguage)
        try? userSettingStore.setTranslateTapToTranslate(tapToTranslate)
        try? userSettingStore.setTagTranslationDisplayMode(tagTranslationDisplayMode)
        try? userSettingStore.setTranslateOpenAIApiKey(openAIApiKey)
        try? userSettingStore.setTranslateOpenAIBaseURL(openAIBaseURL)
        try? userSettingStore.setTranslateOpenAIModel(openAIModel)
        try? userSettingStore.setTranslateOpenAITemperature(openAITemperature)
        try? userSettingStore.setTranslateBaiduAppid(baiduAppid)
        try? userSettingStore.setTranslateBaiduKey(baiduKey)
        try? userSettingStore.setTranslateGoogleApiKey(googleApiKey)
        try? userSettingStore.setTranslateTencentSecretId(tencentSecretId)
        try? userSettingStore.setTranslateTencentSecretKey(tencentSecretKey)
        try? userSettingStore.setTranslateTencentRegion(tencentRegion)
        try? userSettingStore.setTranslateTencentProjectId(tencentProjectId)
    }

    private func createOpenAIService() -> OpenAITranslateService {
        OpenAITranslateService(
            baseURL: openAIBaseURL.isEmpty ? "https://api.openai.com/v1" : openAIBaseURL,
            apiKey: openAIApiKey,
            model: openAIModel.isEmpty ? "gpt-3.5-turbo" : openAIModel,
            temperature: openAITemperature
        )
    }

    private func createBaiduService() -> BaiduTranslateService {
        let config = BaiduTranslateConfig(
            appid: baiduAppid,
            key: baiduKey,
            action: "0"
        )
        return BaiduTranslateService(config: config)
    }

    private func createGoogleAPIService() -> GoogleAPITranslateService {
        GoogleAPITranslateService()
    }

    func testOpenAIService() {
        guard !isTestingOpenAI else { return }
        isTestingOpenAI = true

        Task {
            do {
                let service = createOpenAIService()
                var task = TranslateTask(
                    raw: "Hello World",
                    sourceLanguage: "en",
                    targetLanguage: targetLanguage.isEmpty ? "zh-CN" : targetLanguage
                )
                try await service.translate(&task)

                await MainActor.run {
                    isTestingOpenAI = false
                    if !task.result.isEmpty {
                        toastMessage = "测试成功"
                    } else {
                        toastMessage = "测试成功，但未返回翻译结果"
                    }
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isTestingOpenAI = false
                    toastMessage = "测试失败: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }

    func testBaiduService() {
        guard !isTestingBaidu else { return }
        isTestingBaidu = true

        Task {
            do {
                let service = createBaiduService()
                var task = TranslateTask(
                    raw: "Hello World",
                    sourceLanguage: "en",
                    targetLanguage: targetLanguage.isEmpty ? "zh-CN" : targetLanguage
                )
                try await service.translate(&task)

                await MainActor.run {
                    isTestingBaidu = false
                    if !task.result.isEmpty {
                        toastMessage = "测试成功"
                    } else {
                        toastMessage = "测试成功，但未返回翻译结果"
                    }
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isTestingBaidu = false
                    toastMessage = "测试失败: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }

    private func createGoogleService() -> GoogleTranslateService {
        GoogleTranslateService()
    }

    func testGoogleService() {
        guard !isTestingGoogle else { return }
        isTestingGoogle = true

        Task {
            do {
                let service = createGoogleService()
                var task = TranslateTask(
                    raw: "Hello World",
                    sourceLanguage: "en",
                    targetLanguage: targetLanguage.isEmpty ? "zh-CN" : targetLanguage
                )
                try await service.translate(&task)

                await MainActor.run {
                    isTestingGoogle = false
                    if !task.result.isEmpty {
                        toastMessage = "测试成功"
                    } else {
                        toastMessage = "测试成功，但未返回翻译结果"
                    }
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isTestingGoogle = false
                    toastMessage = "测试失败: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }

    func testGoogleAPIService() {
        guard !isTestingGoogleAPI else { return }
        isTestingGoogleAPI = true

        Task {
            do {
                let service = createGoogleAPIService()
                var task = TranslateTask(
                    raw: "Hello World",
                    sourceLanguage: "en",
                    targetLanguage: targetLanguage.isEmpty ? "zh-CN" : targetLanguage
                )
                try await service.translate(&task)

                await MainActor.run {
                    isTestingGoogleAPI = false
                    if !task.result.isEmpty {
                        toastMessage = "测试成功"
                    } else {
                        toastMessage = "测试成功，但未返回翻译结果"
                    }
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isTestingGoogleAPI = false
                    toastMessage = "测试失败: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }

    private func createBingService() -> BingTranslateService {
        BingTranslateService()
    }

    func testBingService() {
        guard !isTestingBing else { return }
        isTestingBing = true

        Task {
            do {
                let service = createBingService()
                var task = TranslateTask(
                    raw: "Hello World",
                    sourceLanguage: "en",
                    targetLanguage: targetLanguage.isEmpty ? "zh-CN" : targetLanguage
                )
                try await service.translate(&task)

                await MainActor.run {
                    isTestingBing = false
                    if !task.result.isEmpty {
                        toastMessage = "测试成功"
                    } else {
                        toastMessage = "测试成功，但未返回翻译结果"
                    }
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isTestingBing = false
                    toastMessage = "测试失败: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }

    private func createTencentService() -> TencentTranslateService {
        let config = TencentTranslateConfig(
            secretId: tencentSecretId,
            secretKey: tencentSecretKey,
            region: tencentRegion.isEmpty ? "ap-shanghai" : tencentRegion,
            projectId: tencentProjectId.isEmpty ? "0" : tencentProjectId
        )
        return TencentTranslateService(config: config)
    }

    func testTencentService() {
        guard !isTestingTencent else { return }
        isTestingTencent = true

        Task {
            do {
                let service = createTencentService()
                var task = TranslateTask(
                    raw: "Hello World",
                    sourceLanguage: "en",
                    targetLanguage: targetLanguage.isEmpty ? "zh-CN" : targetLanguage
                )
                try await service.translate(&task)

                await MainActor.run {
                    isTestingTencent = false
                    if !task.result.isEmpty {
                        toastMessage = "测试成功"
                    } else {
                        toastMessage = "测试成功，但未返回翻译结果"
                    }
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isTestingTencent = false
                    toastMessage = "测试失败: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TranslationSettingView()
    }
    .frame(maxWidth: 600)
}
