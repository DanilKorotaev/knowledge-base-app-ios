import SwiftUI

struct LogPreviewView: View {
    @StateObject var viewModel: LogPreviewViewModel

    var body: some View {
        List(viewModel.items) { item in
            NavigationLink {
                LogPreviewDetailsView(
                    item: item,
                    delegate: viewModel,
                    initialSearchText: viewModel.searchText
                )
            } label: {
                Text(item.preview)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
            }
            .contextMenu {
                Button("logs.copy_all") { viewModel.didCopyAllRequested(for: item) }
                if viewModel.canCopyCurl(for: item) {
                    Button("logs.copy_curl") { viewModel.didCopyCurlRequested(for: item) }
                }
                if viewModel.canCopyBody(for: item) {
                    Button("logs.copy_body") { viewModel.didCopyBodyRequested(for: item) }
                }
            }
        }
        .onAppear { viewModel.didLoadView() }
        .background(SearchTextFieldConfigurator())
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle("logs.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                // use activity sheet
                Button { viewModel.didShareLogsRequested() } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Button {
                        viewModel.selectedFilters = []
                    } label: {
                        if viewModel.selectedFilters.isEmpty {
                            Label("logs.filter_all", systemImage: "checkmark")
                        } else {
                            Text("logs.filter_all")
                        }
                    }
                    ForEach(viewModel.filters, id: \.self) { filter in
                        Button {
                            if viewModel.selectedFilters.contains(filter) {
                                viewModel.selectedFilters.remove(filter)
                            } else {
                                viewModel.selectedFilters.insert(filter)
                            }
                        } label: {
                            if viewModel.selectedFilters.contains(filter) {
                                Label(filter.text, systemImage: "checkmark")
                            } else {
                                Text(filter.text)
                            }
                        }
                    }
                } label: {
                    Text(filterTitle)
                }
            }
        }
    }

    private var filterTitle: String {
        if viewModel.selectedFilters.isEmpty { return L10n.string("logs.filter_all") }
        return L10n.format("logs.filter_tags_format", viewModel.selectedFilters.count)
    }
}
