import SwiftUI
import ComposableArchitecture

@Reducer
struct FeatureReducer {
  @ObservableState
  struct State: Equatable {
    var items: [Item] = []
    var searchQuery: String = ""
    var isLoading = false
  }

  struct Item: Identifiable, Equatable {
    var id: UUID
    var title: String
    var description: String
    var isFavorite = false

    init(id: UUID = UUID(), title: String, description: String) {
      self.id = id
      self.title = title
      self.description = description
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case itemsLoaded([Item])
    case toggleFavorite(Item.ID)
    case view(View)

    enum View {
      case itemSelected(Item.ID)
      case itemFavoriteToggled(Item.ID)
      case refreshRequested
      case loadItems
    }
  }

  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .view(viewAction):
        switch viewAction {
        case let .itemSelected(id):
          // アイテム選択の処理
          return .none

        case let .itemFavoriteToggled(id):
          return .send(.toggleFavorite(id))

        case .refreshRequested:
          return .send(.view(.loadItems))

        case .loadItems:
          state.isLoading = true
          return .run { send in
            // データのロードをシミュレート
            try await clock.sleep(for: .seconds(1))

            let items = [
              Item(title: "アイテム1", description: "説明1"),
              Item(title: "アイテム2", description: "説明2"),
              Item(title: "アイテム3", description: "説明3")
            ]

            await send(.itemsLoaded(items))
          }
        }

      case let .toggleFavorite(id):
        if let index = state.items.firstIndex(where: { $0.id == id }) {
          state.items[index].isFavorite.toggle()
        }
        return .none

      case let .itemsLoaded(items):
        state.items = items
        state.isLoading = false
        return .none
      }
    }
  }
}

struct FeatureView: View {
  @Perception.Bindable var store: StoreOf<FeatureReducer>

  private func send(_ action: FeatureReducer.Action.View) {
    store.send(.view(action))
  }

  var body: some View {
    NavigationStack {
      VStack {
        // 検索フィールド
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundColor(.gray)
          TextField("検索...", text: $store.searchQuery)
            .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal)

        // リスト
        List {
          ForEach(store.items.filter {
            store.searchQuery.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(store.searchQuery)
          }) { item in
            HStack {
              VStack(alignment: .leading) {
                Text(item.title)
                  .font(.headline)
                Text(item.description)
                  .font(.subheadline)
                  .foregroundColor(.gray)
              }

              Spacer()

              Button {
                send(.itemFavoriteToggled(item.id))
              } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                  .foregroundColor(item.isFavorite ? .yellow : .gray)
              }
              .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
              send(.itemSelected(item.id))
            }
          }
        }
        .listStyle(.plain)
        .refreshable {
          await send(.refreshRequested).finish()
        }
        .overlay {
          if store.isLoading {
            ProgressView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(Color.black.opacity(0.2))
          }
        }
      }
      .navigationTitle("機能名")
      .onAppear {
        send(.loadItems)
      }
    }
  }
}

#Preview {
  FeatureView(
    store: Store(initialState: FeatureReducer.State()) {
      FeatureReducer()
    }
  )
}
