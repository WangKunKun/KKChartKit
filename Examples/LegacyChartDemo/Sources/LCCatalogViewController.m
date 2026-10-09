#import "LCCatalogViewController.h"
#import "LCScenarioViewController.h"
#import "LCScenario.h"

@interface LCCatalogViewController ()
@property (nonatomic, copy) NSArray<LCScenario *> *scenarios;
@end
@implementation LCCatalogViewController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"参考图表 · 旧模块 Demo";
    self.scenarios = LCScenario.catalog;
    self.tableView.rowHeight = 86;
    UILabel *intro = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 88)];
    intro.text = @"直接运行参考目录中的 HMAA / HMLG / HMMT 封装\n本地 AAChartKit + Highcharts 11.4.3\n固定样本用于记录实际行为与后续同数据对比";
    intro.numberOfLines = 0; intro.textAlignment = NSTextAlignmentCenter;
    intro.font = [UIFont systemFontOfSize:12]; intro.textColor = UIColor.secondaryLabelColor;
    self.tableView.tableHeaderView = intro;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.scenarios.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"scenario"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"scenario"];
    LCScenario *scenario = self.scenarios[indexPath.row];
    cell.textLabel.text = scenario.title; cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = scenario.summary; cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.accessibilityIdentifier = [@"scenario." stringByAppendingString:scenario.identifier];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.navigationController pushViewController:[[LCScenarioViewController alloc] initWithScenario:self.scenarios[indexPath.row]] animated:YES];
}
@end
