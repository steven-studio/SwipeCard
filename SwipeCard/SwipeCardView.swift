//
//  SwipeCardView.swift
//  SwipeCard
//
//  Created by 游哲維 on 2025/3/16.
//
//  這個檔案示範一個最簡單的「卡片滑動 + Undo」流程。
//  不需要會程式，也能大概看懂下面的註解：
//    - 我們有幾個「User」資料
//    - 顯示一張卡片，滑出去後就換下一張
//    - 可以按 Undo 撤回上一張卡
//    - 如果卡片都滑完，就顯示一個「圈圈動畫」，告知「沒卡了」
//  下方程式裡還有幾個按鈕（Dislike、Message、Like...），尚未實作任何功能，只是UI示例

import SwiftUI

// MARK: - 使用者資料結構 (Model)
// 每個 User 代表一位使用者，這裡包含了幾個欄位：
//  id: 代表唯一ID
//  name: 名字
//  age: 年齡
//  zodiac: 星座
//  location: 所在地
//  height: 身高
//  photos: 這個使用者的照片(檔名)，可以替換成真實圖片檔名
struct User {
    let id: String
    let name: String
    let age: Int
    let zodiac: String
    let location: String
    let height: Int
    let photos: [String]
}

// MARK: - SwipeCardView 主畫面
// 這個 View 負責整個「卡片堆疊 + 手勢滑動 + Undo + 沒卡動畫」的邏輯
struct SwipeCardView: View {

    // 目前正在顯示第幾張卡 (索引)
    // 例如 currentIndex = 0 -> 顯示users[0]
    @State private var currentIndex = 0
    
    // 卡片拖曳的偏移量 (滑動時會更新)
    // 會影響卡片在畫面上的 x / y 位置
    @State private var offset = CGSize.zero

    // MARK: - UI Controls
    // showCircleAnimation: 如果卡片滑到沒了，就顯示「圈圈動畫」(CircleExpansionView)
    @State private var showCircleAnimation = false
    // showPrivacySettings: 如果想顯示「隱私設定畫面」(目前示例中沒做任何動作)
    @State private var showPrivacySettings = false
    // showWelcomePopup: 是否要顯示一個彈窗(「歡迎Popup」)，可以自行關掉
    @State private var showWelcomePopup = false    // 初始值為 true，代表剛登入時顯示彈出視窗
        
    // 用來存「最後滑掉哪位使用者」( Undo 時需要 )
    // 也會記得「上一張卡」的 index 與「是不是 Like」
    @State private var lastSwipedData: (user: User, index: Int, isRightSwipe: Bool)?

    // 用來記錄「卡片飛出去」的 offset 值，以便 Undo 時可以飛回來
    @State private var lastSwipedOffset: CGSize?
    
    // 喜歡次數 (likeCount)，當右滑 (like) 時就 +1
    @State private var likeCount = 0

    // 模擬幾個假使用者 (每個含 ID / name / age / zodiac / location / height / photos)
    // 你可以把 "userID_2_photo1" 等字串換成真實圖片檔名
    @State private var users: [User] = [
        User(
            id: "userID_2",
            name: "後照鏡被偷",
            age: 20,
            zodiac: "雙魚座",
            location: "桃園市",
            height: 172,
            photos: [
                "userID_2_photo1",
                "userID_2_photo2"
            ]
        ),
        User(
            id: "userID_3",
            name: "小明",
            age: 22,
            zodiac: "天秤座",
            location: "台北市",
            height: 180,
            photos: [
                "userID_3_photo1",
                "userID_3_photo2",
                "userID_3_photo3",
                "userID_3_photo4",
                "userID_3_photo5",
                "userID_3_photo6"
            ]
        ),
        User(
            id: "userID_4",
            name: "小花",
            age: 25,
            zodiac: "獅子座",
            location: "新竹市",
            height: 165,
            photos: [
                "userID_4_photo1",
                "userID_4_photo2",
                "userID_4_photo3"
            ]
        )
        // 你也可以再加更多 User
    ]

    // body: 畫面內容
    var body: some View {
        ZStack {
            // 如果「showCircleAnimation == true」，就顯示「沒有更多卡了」的圈圈動畫
            if showCircleAnimation {
                // 如果「沒卡」了，就秀圈圈動畫
                CircleExpansionView()
            } else {
                // 否則顯示「主卡片」(mainSwipeCardView)
                mainSwipeCardView
            }

            // 右上角擺一個「隱私設定」按鈕(此範例沒實際功能)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        // 顯示隱私設置畫面
                        showPrivacySettings = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.gray)
                            .font(.system(size: 30))
                            .padding(.top, 50)
                            .padding(.trailing, 20)
                    }
                    // 加上識別標識
                    .accessibility(identifier: "privacySettingsButton")
                }
                Spacer()
            }
            
            // 如果 showWelcomePopup == true，就顯示一個彈窗
            // (範例中可以自行按「知道了，開始吧」關掉)
            if showWelcomePopup {
                welcomePopupView
            }
        }
        // 給畫面加個標識
        .accessibilityIdentifier("SwipeCardViewIdentifier")
        // 擴大到整個螢幕
        .edgesIgnoringSafeArea(.all) // 保證圖標能貼近螢幕邊緣
        // 監聽 Notification：.undoSwipeNotification (在子視圖若發這通知就會呼叫 undoSwipe)
        .onReceive(NotificationCenter.default.publisher(for: .undoSwipeNotification)) { _ in
            self.undoSwipe()
            print("Got undo notification!")
        }
    }
    
    // MARK: - 主滑動卡片畫面 (ZStack裡疊幾張卡)
    var mainSwipeCardView: some View {
        ZStack {
            // 從後往前顯示卡片。一次顯示 3 張（或更少，如果剩不到3張）
            // reversed(): 逆序。第一張要疊最上面
            ForEach(Array(users[currentIndex..<min(currentIndex + 3, users.count)]).reversed(), id: \.id) { user in
                // 先用 user.id 找到該使用者在全部 users 的索引
                let index = users.firstIndex(where: { $0.id == user.id }) ?? 0
                // 判斷是不是最上面那張
                let isCurrentCard = index == currentIndex

                // 給卡片一點堆疊的 yOffset (每張卡往下 10pt)
                let baseY = CGFloat(index - currentIndex) * 10
                // 如果是最上面那張，還要加上「手勢拖動的 offset.height」
                let actualY = isCurrentCard ? (baseY + offset.height) : baseY
                // 旋轉角度 (根據 offset.width 來做旋轉)
                let rotationAngle = isCurrentCard ? Double(offset.width / 10) : 0
                // zIndexValue: 控制最上卡疊在上面
                let zIndexValue = Double(users.count - index)
                // scaleValue: 如果不是最上卡，就縮小一點 (0.95)
                let scaleValue = isCurrentCard ? 1.0 : 0.95
                // xOffset: 如果是最上卡，x = offset.width；否則 x = 0
                let xOffset = isCurrentCard ? offset.width : 0

                // 顯示單張卡片
                SwipeCard(user: user)
                    // 設定卡片在畫面的位置
                    .offset(
                        x: isCurrentCard ? offset.width : 0,
                        y: isCurrentCard ? offset.height : CGFloat(index - currentIndex) * 10
                    )
                    // 縮放
                    .scaleEffect(scaleValue)
                    // 旋轉
                    .rotationEffect(.degrees(rotationAngle))
                    // 如果是最上卡，才允許拖曳手勢 (拖動 offset)
                    .gesture(
                        isCurrentCard ? DragGesture()
                            .onChanged { gesture in
                                // 拖曳過程中，不斷更新 offset
                                self.offset = gesture.translation
                            }
                            .onEnded { value in
                                // 拖曳結束，判斷要不要飛出去
                                let predictedX = value.predictedEndTranslation.width
                                let predictedY = value.predictedEndTranslation.height

                                // 如果預估 x > 120，視為右滑 (like)
                                if predictedX > 120 {
                                    // ▶︎ 右滑 (like)
                                    swipeOffScreen(toRight: true, predictedX: predictedX, predictedY: predictedY)
                                }
                                // 如果預估 x < -120，視為左滑 (dislike)
                                else if predictedX < -120 {
                                    // ◀︎ 左滑 (dislike)
                                    swipeOffScreen(toRight: false, predictedX: predictedX, predictedY: predictedY)
                                }
                                // 否則不夠力，就回到中間
                                else {
                                    // 回彈，不夠力就歸位
                                    withAnimation(.spring()) {
                                        offset = .zero
                                    }
                                }
                            }
                        : nil
                    )
                    // 讓頂卡 zIndex 更大，以免被其他卡擋住
                    .zIndex(zIndexValue) // 控制卡片的顯示層級
                    // 不要多餘的自動動畫
                    .animation(nil, value: offset) // 禁止不必要的動畫
            }
        }
    }
    
    // MARK: - 卡片飛出去
    // toRight: true 表示喜歡 (右滑)
    // predictedX, predictedY: 是結束手勢時預估的拖曳量
    func swipeOffScreen(toRight: Bool, predictedX: CGFloat, predictedY: CGFloat) {
        // 決定飛多遠 (這裡用1000)
        let flyDistance: CGFloat = 1000
        // ratio 幫助計算 y / x
        let ratio = predictedY / predictedX
        // finalY: 用 ratio * 1000
        let finalY = ratio * flyDistance
        // finalX: 如果是右滑就 1000，左滑就 -1000
        let finalX = toRight ? flyDistance : -flyDistance
        
        // 執行動畫：飛出去
        withAnimation(.easeOut(duration: 0.4)) {
            offset = CGSize(width: finalX, height: finalY)
        }
        // 記錄：最後飛出去的位置，用於 Undo
        self.lastSwipedOffset = CGSize(width: finalX, height: finalY)

        // 0.4 秒後，正式切到下一張
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // 這裡就可以呼叫 handleSwipe()，或直接做 currentIndex += 1
            handleSwipe(rightSwipe: toRight)
        }
    }
    
    // MARK: - 確定滑掉後，前往下一張
    // rightSwipe: 是否為右滑 (like)
    func handleSwipe(rightSwipe: Bool) {
        // 如果已經滑到底，就不處理
        guard currentIndex < users.count else {
            print("Error: currentIndex 超出陣列範圍，無法繼續滑卡。")
            return
        }
            
        // 紀錄最後一次滑卡資訊，用於 Undo
        self.lastSwipedData = (
            user: self.users[self.currentIndex],
            index: self.currentIndex,
            isRightSwipe: rightSwipe
        )
            
        // 如果是右滑 -> likeCount +1
        if rightSwipe {
            likeCount += 1
        }
            
        // 0.5 秒後，正式前往下一張
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if currentIndex < users.count - 1 {
                currentIndex += 1
            } else {
                // 如果沒有更多卡 -> 顯示圈圈動畫
                withAnimation {
                    showCircleAnimation = true
                }
            }
            // 把 offset 重置
            self.offset = .zero
        }
    }
    
    // MARK: - Undo 撤回
    func undoSwipe() {
        // 如果沒有 lastSwipedData，表示沒東西可撤
        guard let data = lastSwipedData else {
            print("❌ undoSwipe - lastSwipedData == nil，沒有可以撤回的資料")
            // 沒有可以撤回的資料
            return
        }
        print("✅ undoSwipe - lastSwipedData:", data)
            
        // 如果上一張是 like，就把 likeCount 減回來
        if data.isRightSwipe {
            likeCount -= 1
        }
            
        // 將 currentIndex 回到當時
        self.currentIndex = data.index
        
        // 若之前記錄了「飛出去的位置」，就把 offset 放到那裡
        // 這樣畫面就顯示「卡片還在螢幕外」
        if let oldOffset = self.lastSwipedOffset {
            // 先瞬移到飛出去的位置
            self.offset = oldOffset
        } else {
            // 如果沒有記，就假裝在右邊
            self.offset = CGSize(width: 1000, height: 0)
        }
            
        // 延遲 0.2 秒後，再用動畫飛回到原點
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 5.0)) {
                self.offset = .zero
            }
        }
            
        // 如果之前因為沒卡而顯示了圈圈動畫，也要把它關掉
        withAnimation {
            self.showCircleAnimation = false
        }

        // 撤回後，清除 lastSwipedData
        self.lastSwipedData = nil
    }
    
    // MARK: - 位置權限提示畫面 (範例，實際沒做任何 request)
    var locationPermissionPromptView: some View {
        VStack {
            Spacer()
            Image(systemName: "location.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            Text("來認識附近的新朋友吧")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)

            Text("SwiftiDate 需要你的 \"位置權限\" 才能幫你找到附近好友哦")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()

            Button(action: {
                // 假裝要開啟 locationManager
                // locationManager.requestPermission()
            }) {
                Text("前往設置")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(10)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
        .padding()
    }
    
    // MARK: - 歡迎彈窗 (示例)
    var welcomePopupView: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                ZStack {
                    // 置中一個白色方塊
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .frame(width: 300, height: 400)
                        .shadow(radius: 10)
                    
                    VStack {
                        Image(systemName: "person.fill.checkmark")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                            .padding(.top, 40)
                        
                        Text("你喜歡什麼樣類型的？")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        Text("我們會根據你的左滑和右滑了解你喜歡的類型，為你推薦更優質的用戶。")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        
                        Spacer()
                        
                        Button(action: {
                            // 按下後關閉這個彈窗
                            showWelcomePopup = false // 點擊按鈕時關閉彈出視窗
                        }) {
                            Text("知道了，開始吧！")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(10)
                                .padding(.horizontal, 40)
                                .padding(.bottom, 20)
                        }
                    }
                    .padding()
                }
                .frame(width: 300, height: 400)
                Spacer()
            }
        }
    }
}

// MARK: - 單個卡片的顯示視圖
// 這個 View 負責顯示「一位 User」的照片、名字、星座、地點、身高，以及底部幾個按鈕 (Undo / xmark / message / heart / star)
struct SwipeCard: View {
    // 這張卡對應哪位 User
    var user: User
    
    // 若 user 有多張照片，用 currentPhotoIndex 來決定顯示哪一張
    @State private var currentPhotoIndex = 0 // 用來追蹤目前顯示的照片索引

    var body: some View {
        ZStack {
            // 檢查 user.photos 裡是否能顯示
            if user.photos.indices.contains(currentPhotoIndex) {
                Image(user.photos[currentPhotoIndex])
                    .resizable()
                    .scaledToFill()
                    // 讓卡片稍微縮小一點 (width - 20)
                    .frame(maxWidth: UIScreen.main.bounds.width - 20, maxHeight: .infinity)
                    // 四角帶圓角
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    // 邊框
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white, lineWidth: 4))
                    .edgesIgnoringSafeArea(.top)
                    .onTapGesture { value in
                            // 根據點擊位置來切換照片
                            let screenWidth = UIScreen.main.bounds.width
                            let tapX = value.x // 取得點擊的 X 軸座標
                            
                            // 若 x < 螢幕中間，就上一張
                            if tapX < screenWidth / 2 {
                                // 點擊左半邊，切換到上一張
                                if currentPhotoIndex > 0 {
                                    currentPhotoIndex -= 1
                                }
                            } else {
                                // 點擊右半邊，切換到下一張
                                if currentPhotoIndex < user.photos.count - 1 {
                                    currentPhotoIndex += 1
                                }
                            }
                        }
            } else {
                // 如果沒有照片，就顯示一個警示符號
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
            }
            
            // 下方的使用者資料 & 按鈕
            VStack(alignment: .leading, spacing: 5) {
                // 照片上方的「頁碼指示」(比如有幾張照片)
                // user.photos.count 幾張，currentPhotoIndex 是第幾張
                HStack(spacing: 5) {
                    ForEach(0..<user.photos.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .frame(width: 40, height: 8)
                            .foregroundColor(index == currentPhotoIndex ? .white : .gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .padding(.horizontal)
                .cornerRadius(10)
                
                Spacer()
                
                // 底部 VStack
                VStack {
                    Spacer()
                    
                    // 顯示名字與年齡
                    Text("\(user.name), \(user.age)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 星座 / 地點 / 身高
                    HStack(spacing: 10) {
                        // 星座標籤
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.circle.fill") // 替換為合適的星座圖示
                            Text(user.zodiac)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Capsule())

                        // 地點標籤
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill")
                            Text(user.location)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Capsule())

                        // 身高標籤
                        HStack(spacing: 5) {
                            Image(systemName: "ruler")
                            Text("\(user.height) cm")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading) // 讓標籤靠左對齊
                    
                    // 底部放幾個按鈕 (Undo / Dislike / Message / Like / Star)
                    HStack {
                        
                        // MARK: - Undo 按鈕
                        // 按下後用 NotificationCenter 通知父視圖 undo
                        Button(action: {
                            // 呼叫父視圖的 undoSwipe()
                            // 因為這是獨立組件，要嘛用環境變數、要嘛直接改成 @Binding 或 callback
                            // 最簡單方式：把 undoSwipe 寫在父 View，這裡改成通知父層
                            // 可以將 undoSwipe() 搬到 EnvironmentObject 或者用 NotificationCenter 也可以。
                            // 下面示範用 NotificationCenter 為例：
                            NotificationCenter.default.post(name: .undoSwipeNotification, object: nil)
                        }) {
                            ZStack {
                                // 圓形背景
                                Circle()
                                    .fill(Color.gray.opacity(0.8))
                                    .frame(width: 50, height: 50) // 設定圓的大小
                                
                                VStack {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.title)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        
                        Spacer() // 按鈕之間的彈性間距
                        
                        // Dislike (xmark) 按鈕 (尚未實作)
                        Button(action: {
                            // 這裡可以做 left-swipe 也可以
                        }) {
                            ZStack {
                                // 圓角矩形背景
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(Color.gray.opacity(0.8))
                                    .frame(width: 70, height: 50) // 設定矩形的大小
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 30, weight: .bold)) // 設定字體大小和粗體
                                    .foregroundColor(.red)
                                    // 加上識別標識
                                    .accessibility(identifier: "xmarkButtonImage")
                            }
                        }
                        
                        Spacer() // 按鈕之間的彈性間距

                        // Message 按鈕 (尚未實作)
                        Button(action: {
                            // 做你想做的
                        }) {
                            ZStack {
                                // 圓形背景
                                Circle()
                                    .fill(Color.gray.opacity(0.8))
                                    .frame(width: 50, height: 50) // 設定圓的大小
                                
                                // 用 .gold 顏色可能需要自訂
                                VStack {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gold)
                                }
                            }
                        }
                        
                        Spacer() // 按鈕之間的彈性間距

                        // Like 按鈕 (heart)
                        Button(action: {
                            // 這裡可以做 right-swipe
                        }) {
                            ZStack {
                                // 圓角矩形背景
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(Color.gray.opacity(0.8))
                                    .frame(width: 70, height: 50) // 設定矩形的大小
                                
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 24, weight: .bold)) // 設定字體大小和粗體
                                    .foregroundColor(.green)
                                    // 加上識別標識
                                    .accessibility(identifier: "heartFillButtonImage")
                            }
                        }
                        
                        Spacer() // 按鈕之間的彈性間距

                        // Star (用來示範其他功能)
                        Button(action: {
                            // Special feature action
                        }) {
                            ZStack {
                                // 圓形背景
                                Circle()
                                    .fill(Color.gray.opacity(0.8))
                                    .frame(width: 50, height: 50) // 設定圓的大小
                                
                                VStack {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 24))
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        // 設定「卡片」的可視大小 (依螢幕大小而定)
        .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height - 200)
        // 給卡片加點陰影
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)  // <--- 加上這裡
    }
}

// MARK: - 自訂 Notification Name，給 Undo 用
extension Notification.Name {
    static let undoSwipeNotification = Notification.Name("undoSwipeNotification")
}

// MARK: - 預覽 (Preview)
struct SwipeCardView_Previews: PreviewProvider {
    static var previews: some View {
        // 這裡展示在 iPhone 15 Pro Max 模擬器
        SwipeCardView()
            .previewDevice("iPhone 15 Pro Max") // ✅ 指定預覽設備
    }
}
