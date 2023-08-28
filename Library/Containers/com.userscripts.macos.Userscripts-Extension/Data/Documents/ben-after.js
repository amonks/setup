{
  action: async (stateObj, index, array) => {
    let randomIndex = Math.floor(Math.random() * stateObj.playerDeck.length);
    let cardIndex = 0;
    upgradeAnimation(
      stateObj,
      randomIndex,
      1 + array[index].upgrades,
      (divIDName = "handContainer2")
    );

    await timeout(array[index].timeValue);

    stateObj = immer.produce(stateObj, (newState) => {
      console.log("upgrading " + newState.playerDeck[randomIndex].name);
      newState.playerDeck[randomIndex].upgrades += 1 + array[index].upgrades;
      newState.playerMonster.encounterEnergy -= array[index].baseCost;
      if (
        stateObj.encounterHand.find(
          (card) => card.name === stateObj.playerDeck[randomIndex].name
        )
      ) {
        console.log(
          "found card " + stateObj.playerDeck[randomIndex].name + " in hand"
        );
        cardIndex = newState.encounterHand.findIndex(
          (card) => card.name === stateObj.playerDeck[randomIndex].name
        );
        newState.encounterHand[cardIndex].upgrades += 1 + array[index].upgrades;
        console.log(
          "card upgrades after upgrading is " +
            newState.encounterHand[cardIndex].upgrades
        );
      } else {
        console.log("did not find card in hand");
      }
    });
    console.log(
      "after upgrading, card has" + stateObj.encounterHand[cardIndex].upgrades
    );
    return stateObj;
  };
}
