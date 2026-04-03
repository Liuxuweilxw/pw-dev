import '../models/app_models.dart';

const List<RoomItem> mockRooms = [
  RoomItem(
    id: 'R-12015',
    title: '高效上分四排车',
    owner: '夜行老板',
    price: 320,
    status: '待加入',
    seatsLeft: 2,
    contribution: '老板60% / 陪玩40%',
    note: '20:00-23:00，要求沟通顺畅，KD>2.0。',
    commission: 240,
    tags: ['限时', '高分段'],
  ),
  RoomItem(
    id: 'R-12016',
    title: '新手教学陪跑',
    owner: '芒果老板',
    price: 180,
    status: '进行中',
    seatsLeft: 1,
    contribution: '老板50% / 陪玩50%',
    note: '偏教学，语音友好，预计2小时。',
    commission: 135,
    tags: ['新手房间'],
  ),
  RoomItem(
    id: 'R-12017',
    title: '冲榜冲刺房',
    owner: 'K总',
    price: 800,
    status: '待加入',
    seatsLeft: 3,
    contribution: '老板70% / 陪玩30%',
    note: '100%大额需求候选，求稳定高强度输出。',
    commission: 560,
    tags: ['大额候选', '紧急'],
  ),
];

const List<WalletFlowItem> mockWalletFlows = [
  WalletFlowItem(
    type: '充值',
    amount: '+5000',
    status: '成功',
    time: '04-01 21:20',
  ),
  WalletFlowItem(
    type: '订单消费',
    amount: '-320',
    status: '成功',
    time: '04-01 22:41',
  ),
  WalletFlowItem(
    type: '佣金结算',
    amount: '+240',
    status: '处理中',
    time: '04-02 00:05',
  ),
  WalletFlowItem(
    type: '提现',
    amount: '-800',
    status: '处理中',
    time: '04-02 09:12',
  ),
];

const List<OrderItem> mockOrders = [
  OrderItem(
    id: 'O-20260401-001',
    partner: '夜行老板',
    unitPrice: 320,
    ratio: '60/40',
    progress: '已完成待结算',
    room: '高效上分四排车',
  ),
  OrderItem(
    id: 'O-20260401-002',
    partner: '芒果老板',
    unitPrice: 180,
    ratio: '50/50',
    progress: '进行中',
    room: '新手教学陪跑',
  ),
];
