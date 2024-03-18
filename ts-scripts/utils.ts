export const convertIntToHexLensId = (profileId: string) => {
    let hexProfileId = parseInt(profileId).toString(16);
    // If the hex parsed profile id is an odd number length then it needs to be padded with a zero after the 0x
    if (hexProfileId.length % 2 !== 0) {
        hexProfileId = "0x0" + hexProfileId;
    } else {
        hexProfileId = "0x" + hexProfileId;
    }
    return hexProfileId;
};