class RemoteMarketQuote {
  final String ingredientId;
  final String market;
  final double unitPrice;
  final bool isCampaign;
  final String campaignLabelTr;
  final String campaignLabelEn;

  const RemoteMarketQuote({
    required this.ingredientId,
    required this.market,
    required this.unitPrice,
    required this.isCampaign,
    required this.campaignLabelTr,
    required this.campaignLabelEn,
  });
}
