import { NavigationService } from '../services/NavigationService';
import { HistoryPage } from './HistoryPage';
import { HomePage } from './HomePage';
import { common } from '@kit.AbilityKit';
import GlobalContext from '../utils/GlobalContext';

@Entry
@Component
struct Index {
  navigationService: NavigationService = NavigationService.getInstance();

  @Builder
  routeMap(name: string) {
    NavDestination() {
      if (name === 'HomePage') {
        HomePage()
      } else if (name === 'HistoryPage') {
        HistoryPage()
      }
    }
    .onBackPressed(() => {
      if (name === 'HomePage') {
        this.terminateApp();
        return true;
      }
      return false;
    })
    .hideTitleBar(true)
  }

  build() {
    Navigation(this.navigationService.pageInfos)
      .onAppear(() => {
        this.navigationService.navigateTo('HomePage');
      })
      .mode(NavigationMode.Stack)
      .navDestination(this.routeMap)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
      .hideTitleBar(true)
      .width('100%')
      .height('100%')
  }

  private terminateApp() {
    const context = GlobalContext.getInstance().getCntx() as common.UIAbilityContext;
    if (context) {
      context.terminateSelf();
    }
  }
}
