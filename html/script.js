let currentDutyState = null;

window.addEventListener('message', function (event) {
    if (event.data.type === "openDutyMenu") {
        document.body.style.display = "flex";
        currentDutyState = event.data.currentDuty || null;
    }
});

function confirmDuty() {
    const department = document.getElementById("department").value;
    const playerName = document.getElementById("playerName").value.trim();
    const callsign = document.getElementById("callsign").value.trim();

    // Validate required fields
    if (!playerName) {
        alert("Please enter your name");
        return;
    }

    if (!callsign) {
        alert("Please enter your callsign");
        return;
    }

    // Determine if going on or off duty
    const onDuty = !currentDutyState;

    fetch(`https://${GetParentResourceName()}/setDuty`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
            onDuty, 
            department,
            playerName,
            callsign
        })
    });
    
    document.body.style.display = "none";
    
    // Clear form
    document.getElementById("playerName").value = "";
    document.getElementById("callsign").value = "";
}

function closeMenu() {
    fetch(`https://${GetParentResourceName()}/closeMenu`, {
        method: 'POST'
    });
    document.body.style.display = "none";
    
    // Clear form
    document.getElementById("playerName").value = "";
    document.getElementById("callsign").value = "";
}