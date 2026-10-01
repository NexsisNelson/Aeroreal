import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

export 'package:font_awesome_flutter/font_awesome_flutter.dart' show FaIconData;

class AppIcon extends FaIcon {
  const AppIcon(
    super.icon, {
    super.key,
    super.size,
    super.fill,
    super.weight,
    super.grade,
    super.opticalSize,
    super.color,
    super.shadows,
    super.semanticLabel,
    super.textDirection,
    super.applyTextScaling,
    super.blendMode,
    super.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? IconTheme.of(context).size ?? 24;
    return SizedBox.square(
      dimension: iconSize,
      child: FittedBox(fit: BoxFit.scaleDown, child: super.build(context)),
    );
  }
}

class AppIcons {
  static const accountBalance = FontAwesomeIcons.buildingColumns;
  static const accountBalanceWalletOutlined = FontAwesomeIcons.wallet;
  static const add = FontAwesomeIcons.plus;
  static const addBox = FontAwesomeIcons.squarePlus;
  static const addBoxOutlined = FontAwesomeIcons.squarePlus;
  static const addCircleOutline = FontAwesomeIcons.circlePlus;
  static const addRounded = FontAwesomeIcons.plus;
  static const analyticsOutlined = FontAwesomeIcons.chartLine;
  static const arrowBackIosNew = FontAwesomeIcons.angleLeft;
  static const arrowBackIosRounded = FontAwesomeIcons.angleLeft;
  static const arrowDownward = FontAwesomeIcons.arrowDown;
  static const arrowDownwardRounded = FontAwesomeIcons.arrowDown;
  static const arrowForwardRounded = FontAwesomeIcons.arrowRight;
  static const arrowUpward = FontAwesomeIcons.arrowUp;
  static const arrowUpwardRounded = FontAwesomeIcons.arrowUp;
  static const articleOutlined = FontAwesomeIcons.newspaper;
  static const attachMoney = FontAwesomeIcons.dollarSign;
  static const barChartRounded = FontAwesomeIcons.chartColumn;
  static const bolt = FontAwesomeIcons.bolt;
  static const check = FontAwesomeIcons.check;
  static const checkCircle = FontAwesomeIcons.circleCheck;
  static const checkCircleOutline = FontAwesomeIcons.circleCheck;
  static const checkRounded = FontAwesomeIcons.check;
  static const chevronRight = FontAwesomeIcons.angleRight;
  static const circle = FontAwesomeIcons.circle;
  static const circleOutlined = FontAwesomeIcons.circle;
  static const coffee = FontAwesomeIcons.mugHot;
  static const copy = FontAwesomeIcons.copy;
  static const creditCard = FontAwesomeIcons.creditCard;
  static const descriptionOutlined = FontAwesomeIcons.fileLines;
  static const deleteOutline = FontAwesomeIcons.trashCan;
  static const dnsOutlined = FontAwesomeIcons.server;
  static const errorOutline = FontAwesomeIcons.circleExclamation;
  static const favoriteBorder = FontAwesomeIcons.heart;
  static const helpOutline = FontAwesomeIcons.circleQuestion;
  static const hexagonOutlined = FontAwesomeIcons.hexagon;
  static const history = FontAwesomeIcons.clockRotateLeft;
  static const home = FontAwesomeIcons.house;
  static const homeOutlined = FontAwesomeIcons.house;
  static const image = FontAwesomeIcons.image;
  static const imageOutlined = FontAwesomeIcons.image;
  static const infoOutline = FontAwesomeIcons.circleInfo;
  static const link = FontAwesomeIcons.link;
  static const localCafe = FontAwesomeIcons.mugHot;
  static const localOfferOutlined = FontAwesomeIcons.tag;
  static const locationCity = FontAwesomeIcons.city;
  static const lockOutline = FontAwesomeIcons.lock;
  static const mailOutline = FontAwesomeIcons.envelope;
  static const monetizationOn = FontAwesomeIcons.coins;
  static const navigateBefore = FontAwesomeIcons.arrowLeft;
  static const notificationsNone = FontAwesomeIcons.bell;
  static const notificationsNoneRounded = FontAwesomeIcons.bell;
  static const notificationsOutlined = FontAwesomeIcons.bell;
  static const openInNew = FontAwesomeIcons.arrowUpRightFromSquare;
  static const person = FontAwesomeIcons.user;
  static const phoneOutlined = FontAwesomeIcons.phone;
  static const pieChart = FontAwesomeIcons.chartPie;
  static const pieChartOutline = FontAwesomeIcons.chartPie;
  static const public = FontAwesomeIcons.globe;
  static const receiptLong = FontAwesomeIcons.receipt;
  static const receiptLongOutlined = FontAwesomeIcons.receipt;
  static const refresh = FontAwesomeIcons.arrowRotateRight;
  static const restartAlt = FontAwesomeIcons.arrowRotateLeft;
  static const savingsOutlined = FontAwesomeIcons.piggyBank;
  static const schedule = FontAwesomeIcons.clock;
  static const science = FontAwesomeIcons.flask;
  static const search = FontAwesomeIcons.magnifyingGlass;
  static const searchOutlined = FontAwesomeIcons.magnifyingGlass;
  static const searchRounded = FontAwesomeIcons.magnifyingGlass;
  static const send = FontAwesomeIcons.paperPlane;
  static const sellOutlined = FontAwesomeIcons.tag;
  static const settings = FontAwesomeIcons.gear;
  static const settingsOutlined = FontAwesomeIcons.gear;
  static const shieldOutlined = FontAwesomeIcons.shield;
  static const shoppingBagOutlined = FontAwesomeIcons.bagShopping;
  static const shoppingCartOutlined = FontAwesomeIcons.cartShopping;
  static const smartToyOutlined = FontAwesomeIcons.robot;
  static const star = FontAwesomeIcons.star;
  static const starBorder = FontAwesomeIcons.star;
  static const starBorderRounded = FontAwesomeIcons.star;
  static const storageOutlined = FontAwesomeIcons.database;
  static const storefront = FontAwesomeIcons.shop;
  static const storefrontOutlined = FontAwesomeIcons.shop;
  static const swapHoriz = FontAwesomeIcons.arrowRightArrowLeft;
  static const token = FontAwesomeIcons.coins;
  static const trendingUp = FontAwesomeIcons.arrowTrendUp;
  static const tune = FontAwesomeIcons.sliders;
  static const verified = FontAwesomeIcons.circleCheck;
  static const verifiedOutlined = FontAwesomeIcons.circleCheck;
  static const verifiedUser = FontAwesomeIcons.shieldHalved;
  static const warningAmberRounded = FontAwesomeIcons.triangleExclamation;
  static const waterDrop = FontAwesomeIcons.droplet;
  static const waterDropOutlined = FontAwesomeIcons.droplet;
  static const workspacePremium = FontAwesomeIcons.award;
  static const cloudOff = FontAwesomeIcons.cloud;
  static const emailOutlined = FontAwesomeIcons.envelope;
}
